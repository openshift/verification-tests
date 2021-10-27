require 'base64'
require 'json'

require 'cli_executor'
require 'admin_credentials'
require 'user_manager'
require 'host'
require 'cucuhttp'
require 'net'
require 'rest'
require 'openshift/node'
require 'webauto/webconsole_executor'

module BushSlicer
  # @note class represents a generic test environment
  class Environment
    include Common::Helper

    attr_reader :opts

    # @param opts [Hash] initialization options
    def initialize(**opts)
      @opts = opts
    end

    # return environment key, mainly useful for logging purposes
    def key
      opts[:key]
    end

    def client_proxy
      opts[:client_proxy]
    end

    # environment may have pre-defined static users used for upgrade testing
    #   or other special purposes like admin user for example
    # @return [Hash<Hash>] a hash of user symbolic names pointing at a hash
    #   of user constructor parameters, e.g.
    #   {u1: "user1:password1", u2: ":tokenstring"}
    private def static_users
      opts[:static_users_map] || {}
    end

    # @return [Object] static user specification to be parsed by user manager
    # @see #static_users
    def static_user_spec(symbolic_name)
      static_users[symbolic_name.to_sym]
    end

    def clean_up
    end
  end

  class OCMEnvironment < Environment
    def web_console_url
      opts[:web_console_url] || raise("web console URL not specified")
    end

    def static_user(type)
      user_spec = static_user_spec(type)
      unless user_spec
        raise "could not find user type '#{type}' defined"
      end

      # TODO: create proper ocm user class, but this is enough for a PoC
      user = OpenStruct.new
      user.loginname, user.password = user_spec.split(":", 2)
      return user.freeze
    end
  end

  # @note this class represents an OpenShift cluster test environment
  class OpenShiftEnvironment < Environment
    # :master represents register, scheduler, etc.
    MANDATORY_OPENSHIFT_ROLES = []
    OPENSHIFT_ROLES = MANDATORY_OPENSHIFT_ROLES + [:master, :node, :lb, :etcd, :bastion]

    # e.g. you call `#node_hosts to get hosts with the node service`
    OPENSHIFT_ROLES.each do |role|
      define_method("#{role}_hosts") do
        hosts.select {|h| h.has_role?(role)}
      end
    end

    # @param opts [Hash] initialization options
    def initialize(**opts)
      super
      @hosts = []
    end

    def user_manager
      @user_manager ||= case opts[:user_manager]
      when nil, "", "auto"
        case opts[:user_manager_users]
        when nil, ""
          raise "automatic OCP htpasswd user creaton not implemented yet"
        when /^pool:/
          PoolUserManager.new(self, **opts)
        else
          StaticUserManager.new(self, **opts)
        end
      else
        BushSlicer.const_get(opts[:user_manager]).new(self, **opts)
      end
    end
    alias users user_manager

    def cli_executor
      @cli_executor ||= BushSlicer.const_get(opts[:cli]).new(self, **opts)
    end

    def admin
      @admin ||= admin_creds.get
    end

    # @return [Boolean] true if we have means to execute admin cli commands and
    #   rest requests
    def admin?
      opts[:admin_creds] && ! opts[:admin_creds].empty?
    end

    def is_admin?(obj)
      admin? && @admin && @admin == obj
    end

    private def admin_creds
      if admin?
        cred_opts = opts.reduce({}) { |m, (k,v)|
          if k.to_s.start_with? "admin_creds_"
            m[k.to_s.gsub(/^admin_creds_/, "").to_sym] = v
          end
          m
        }
        BushSlicer.const_get(opts[:admin_creds]).new(self, **cred_opts)
      else
        raise UnsupportedOperationError,
          "we cannot run as admins in this environment"
      end
    end

    def webconsole_executor
      @webconsole_executor ||= WebConsoleExecutor.new(self, **opts)
    end

    def rest_request_executor
      Rest::RequestExecutor
    end

    def api_proto
      opts[:api_proto] || "https"
    end

    def api_port
      opts[:api_port] || "80"
    end

    def api_port_str
      api_port == '80' ? "" : ":#{opts[:api_port]}"
    end

    def api_hostname
      api_host.hostname
    end

    def api_host
      opts[:api_host] || ((lb_hosts.empty?) ? master_hosts.first : lb_hosts.first)
    end

    def api_endpoint_url
      opts[:api_url] || "#{api_proto}://#{api_hostname}#{api_port_str}"
    end

    def web_console_url
      opts[:web_console_url] || api_endpoint_url
    end

    def admin_console_url
      unless @admin_console_url
        if opts[:admin_console_url]
          @admin_console_url = opts[:admin_console_url]
        else
          consoleproject = Project.new(name: "openshift-console", env: self)
          consoleservice = Service.new(name: "console", project: consoleproject )
          consoleroute = Route.new(name: "console", project: consoleproject, service: consoleservice)
          @admin_console_url = "https://" + consoleroute.dns(by: admin)
        end
      end
      return @admin_console_url
    end

    def idp
      unless @idp
        if opts[:idp]
          @idp = opts[:idp]
        else
          @idp = ''
        end
      end
      return @idp
    end

    def ocm_env
      unless @ocm_env
        if opts[:ocm_env]
          @ocm_env = opts[:ocm_env]
        else
          @ocm_env = ''
        end
      end
      return @ocm_env
    end

    def authentication_url
      unless @authentication_url
        if opts[:authentication_url]
          @authentication_url= opts[:authentication_url]
        else
          authenticationproject = Project.new(name: "openshift-authentication", env: self)
          authenticationservice = Service.new(name: "openshift-authentication", project: authenticationproject )
          authenticationroute = Route.new(name: "oauth-openshift", project: authenticationproject, service: authenticationservice)
          @authentication_url = "https://" + authenticationroute.dns(by: admin)
        end
      end
      return @authentication_url
    end

    # add env var to set some parameters for logging testing
    # for example:
    # logging_envs:
    #   clo:
    #     catsrc: "test"
    #     channel: "4.1"
    #   eo:
    #     catsrc: "redhat"
    #     channel: "5.1"
    # any of the above vars can be nil/empty
    def logging_envs
      unless @logging_envs
        if opts[:logging_envs]
          @logging_envs = opts[:logging_envs]
        else
          @logging_envs = ''
        end
      end
      return @logging_envs
    end

    def descheduler_envs
      unless @descheduler_envs
        if opts[:descheduler_envs]
          @descheduler_envs = opts[:descheduler_envs]
        else
          @descheduler_envs = ''
        end
      end
      return @descheduler_envs
    end

    # naming scheme is https://logs.<cluster_id>.openshift.com for Online
    # for OCP it's https://logs.<subdomain>.openshift.com
    def logging_console_url
      if admin?
        route = self.router_default_subdomain(user: 'admin', project: 'default')
        opts[:logging_console_url] = "https://logs." + route
      else
        # no admin privilege
        opts[:logging_console_url] || web_console_url.gsub('console.', 'logs.')
      end
    end

    # naming scheme is
    # https://metrics.<cluster_id>.openshift.com/hawkular/
    def metrics_console_url
      if admin?
        route = self.router_default_subdomain(user: 'admin', project: 'default')
        opts[:metrics_console_url] = "https://metrics." + route + "/hawkular"
      else
        opts[:metrics_console_url] || web_console_url.gsub('console.', 'metrics.') + "/hawkular"
      end
    end

    # @return docker repo host[:port] used to launch env by checking one of the
    #   system image streams in the `openshift` project
    # @note dc/router could be used as well but will require admin
    def system_docker_repo
      unless @system_docker_repo
        is = ImageStream.new(name: "jenkins",
                             project: Project.new(name: "openshift", env: self))
        imageref = is.latest_tag_status(user: users[0]).imageref
        raise "image stream #{is.name} does not have image for latest tag" if imageref.nil?
        @system_docker_repo = imageref.repo
        unless @system_docker_repo.empty? || @system_docker_repo.end_with?("/")
          @system_docker_repo = "#{@system_docker_repo}/"
        end
      end
      return @system_docker_repo
    end

    # helper parser
    def parse_version(ver_str)
      ver = ver_str.sub(/(^v|^openshift-clients-)/,"")
      if ver !~ /^\d[.]\d+\b.*$/
        raise "version '#{ver}' does not match /^\d[.]\d+\b.*$/"
      end
      ver = ver.split(".").reject(&:empty?).map(&:to_i)
      [ver[0], ver[1]].map(&:to_i)
    end

    # returns the major and minor version using REST
    # @return [Array<String>] raw version, major and minor number
    def get_version(user:)
      if opts[:version]
        _version = opts[:version]
      elsif admin?
        res = admin.cli_exec(:get, resource: "clusterversion", resource_name: "version", o: "jsonpath={.status.desired.version}")
        _version = res[:response].to_s
      else
        raise "cluster version not set and getting without admin access not possible presently"
      end
      @major_version, @minor_version = parse_version(_version)
      return _version, @major_version, @minor_version

      # obtained = user.rest_request(:version)
      # if obtained[:request_opts][:url].include?("/version/openshift") &&
      #     !obtained[:success]
      #   obtained[:props] = {}
      #   obtained[:props][:openshift] = "v4.1"
      #   @major_version = obtained[:props][:major] = 4
      #   @minor_version = obtained[:props][:minor] = 1
      # elsif obtained[:success]
      #   @major_version = obtained[:props][:major].to_i
      #   @minor_version = obtained[:props][:minor].to_i
      # else
      #   raise "error getting version: #{obtained[:error].inspect}"
      # end
      # return obtained[:props][:openshift].sub(/^v/,""), @major_version, @minor_version
    end

    # some rules and logic to compare given version to current environment
    # @return [Integer] less than 0 when env is older, 0 when it is comparable,
    #   more than 0 when environment is newer
    # @note for compatibility reasons we only compare only major and minor
    def version_cmp(version, user:)
      # figure out local environment version
      unless @major_version && @minor_version
        raw_version, @major_version, @minor_version = get_version(user: user)
      end

      major, minor = parse_version(version)

      # lets compare version
      if @major_version == major
        return @minor_version - minor
      else
        return @major_version - major
      end
    end

    def version_ge(version, user:)
      version_cmp(version, user: user) >= 0
    end

    def version_gt(version, user:)
      version_cmp(version, user: user) > 0
    end

    def version_le(version, user:)
      version_cmp(version, user: user) <= 0
    end

    def version_lt(version, user:)
      version_cmp(version, user: user) < 0
    end

    def version_eq(version, user:)
      version_cmp(version, user: user).equal? 0
    end

    # obtain router detals like default router subdomain and router IPs
    # @param user [BushSlicer::User]
    # @param project [BushSlicer::project]
    def get_routing_details(user:, project:, obj:)
      service_res = Service.create(by: user, project: project, spec: "#{BushSlicer::HOME}/testdata/networking/service_with_selector.json")
      raise "cannot create service" unless service_res[:success]
      service = service_res[:resource]

      ## create a dummy route
      route = service.expose(user: user)

      fqdn = route.dns(by: user)
      if obj == 'subdomain'
        opts[:router_subdomain] = fqdn.split('.',2)[1]
      else
        opts[:router_ips] = Common::Net.dns_lookup(fqdn, multi: true)
      end
      raise unless route.delete(by: user)[:success]
      raise unless service.delete(by: user)[:success]
    end

    def router_ips(user:, project:)
      unless opts[:router_ips]
        get_routing_details(user: user, project: project, obj: 'ips')
      end

      return opts[:router_ips]
    end

    def router_default_subdomain(user:, project:)
      unless opts[:router_subdomain]
        get_routing_details(user: user, project: project, obj: 'subdomain')
      end
      return opts[:router_subdomain]
    end

    # get environment supported API paths
    # TODO: need to make this call authenticated,
    #   see https://github.com/openshift/openshift-apiserver/pull/18
    # def api_paths
    #   return @api_paths if @api_paths
    #
    #   opts = {:max_redirects=>0,
    #           :url=>api_endpoint_url,
    #           :method=>"GET"
    #   }
    #   res = Http.http_request(**opts)
    #
    #   unless res[:success]
    #     raise "could not get API paths, see log"
    #   end
    #
    #   return @api_paths = JSON.load(res[:response])["paths"]
    # end

    # get latest API version supported by server
    # def api_version
    #   return @api_version if @api_version
    #   idx = api_paths.rindex{|p| p.start_with?("/api/v")}
    #   return @api_version = api_paths[idx][5..-1]
    # end

    def nodes(user: admin, refresh: false, quiet: true)
      return @nodes if @nodes && !refresh
      @nodes ||= []
      @nodes = @nodes.concat(Node.list(user: user, get_opts: {_quiet: quiet}))
    end

    # @return [Project] a project unique to this executor for test framework
    #   support purposes (e.g. host a debug pod for running node commands)
    def service_project
      unless @service_project
        # if the cluster set the default scheduler, set the project running debug pod node-selector=''
        # to overwrite the default scheduler, or the pod can not be run successfully
        project_name = "proj-" + EXECUTOR_NAME.downcase
        project = Project.new(name: project_name, env: self)
        unless project.active?
          # 60 seconds is no longer enough
          project.wait_to_disappear(admin, 120)
          res = project.create(by: admin, clean_up_registered: true)
          unless res[:success]
            raise "failed to create service project #{project.name}, see log"
          end
          admin.cli_exec(:annotate, resource: "namespace", resourcename: project_name, keyval: 'openshift.io/node-selector=', overwrite: true)
          # we must update the cache, since we just waited for the previously active project to disappear
          project.reload
        end
        @service_project = project
      end
      return @service_project
    end

    # selects the correct configured IAAS provider
    def iaas
      # check if we have a ssh connection to the master nodes.
      self.master_hosts.each { |master|
        raise "The master node #{master.hostname}, is not accessible via SSH!" unless master.accessible?[:success]
      }
      @iaas ||= IAAS.select_provider(self)
    end

    def master_services
      @master_services_type ||= BushSlicer::Platform::MasterService.type(self.master_hosts.first)
      @master_services ||= self.master_hosts.map { |host|
        @master_services_type&.new(host, self)
      }
    end

    # def node_services
    #   @node_services ||= self.nodes.map(&:service)
    # end

    def clean_up
      @user_manager.clean_up if @user_manager
      @hosts.each {|h| h.clean_up } if @hosts
      if @service_project
        @service_project.delete_graceful(by: nil)
        @service_project = nil
      end
      @cli_executor.clean_up if @cli_executor
      @webconsole_executor.clean_up if @webconsole_executor
      super
    end

    def local_storage_provisioner_project
      unless @local_storage_provisioner_project
        project_name = opts[:local_storage_provisioner_project] || "local-storage"
        @local_storage_provisioner_project = Project.new(name: project_name, env: self)
      end
      return @local_storage_provisioner_project
    end

    # return nil is no proxy enabled, else proxy value
    # TODO: as alternative that's not OCP version dependent, but require parsing
    # YAML, we can do:
    #  grep HTTP_PROXY /etc/origin/master/master-config.yaml
    #
    def proxy
      # TODO: return value from https://docs.openshift.com/container-platform/4.2/networking/enable-cluster-wide-proxy.html#nw-proxy-configure-object_config-cluster-wide-proxy
      raise "not implemented"
    end
  end

  # a quickly made up environment class for the PoC
  class StaticEnvironment < OpenShiftEnvironment
    def initialize(**opts)
      super

      if ! opts[:hosts] || opts[:hosts].empty?
        raise "environment should have at least one host running all services"
      end
    end

    def hosts
      if @hosts.empty?
        hlist = parse_hosts_spec
        missing_roles = MANDATORY_OPENSHIFT_ROLES.reject{|r| hlist.find {|h| h.has_role?(r)}}
        unless missing_roles.empty?
          raise "environment does not have hosts with roles: " +
            missing_roles.to_s
        end

        hlist.each do |host|
          # so far masters are always also nodes but labels not always set
          if host.roles.include?(:master) && !host.roles.include?(:node)
            host.roles << :node
          end

          # handle client proxy
          proxy_spec = host.roles.find { |r| r.to_s.start_with? "proxy__" }

          if proxy_spec
            _role, proto, port, username, password = proxy_spec.to_s.split("__")
            if username
              auth_str = "#{username}:#{Base64.decode64 password}@"
            else
              auth_str = ""
            end
            self.client_proxy = "#{proto}://#{auth_str}#{host.hostname}:#{port}"
          end
        end

        hlist.each {|h| h.apply_flags(hlist - [h])}

        @hosts.concat hlist
      end
      return @hosts
    end

    def client_proxy
      if defined? @client_proxy
        @client_proxy
      elsif super
        @client_proxy = super
      else
        hosts
        return @client_proxy
      end
    end

    # set proxy URL only if not already set
    def client_proxy=(url)
      unless defined? @client_proxy
        @client_proxy = url
      end
    end

    # add a new host to environment with defaults
    # usually used to add node hosts discovered dynamically
    def host_add(hostname, **opts)
      raise "new hosts need roles but none given" if opts[:roles].empty?
      host = parse_hosts_spec(spec: "#{opts.delete(:flags)}#{hostname}:#{opts.delete(:roles).join(':')}", **opts).first
      host.apply_flags(@hosts)
      @hosts << host
      return host
    end

    # generate hosts based on spec like: hostname1:role1:role2,hostname2:r3
    private def parse_hosts_spec(spec: opts[:hosts], type: opts[:hosts_type], **additional_opts)
      host_type = BushSlicer.const_get(type)
      return host_type.from_spec(spec, **opts, **additional_opts)
    end
  end
end
