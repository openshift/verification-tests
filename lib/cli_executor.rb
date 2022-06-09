require "base64"
require 'openssl'
require 'yaml'

require 'rules_command_executor'

module BushSlicer
  class CliExecutor
    include Common::Helper

    RULES_DIR = File.expand_path(HOME + "/lib/rules/cli")
    LOGIN_TIMEOUT = 20 # seconds
    CENSOR_LOGS = [
      'create_token',
      'serviceaccounts_get_token',
      'whoami',
    ]

    attr_reader :opts

    def initialize(env, **opts)
      @opts = opts
    end

    # @param [BushSlicer::User, BushSlicer::APIAccessor] user user to execute
    #   command with
    # @param [Symbol] key command key
    # @param [Hash] opts command options
    # @return [BushSlicer::ResultHash]
    def exec(user, key, opts={})
      raise
    end

    private def version
      return opts[:cli_version]
      # this method needs to be overwriten per executor to find out version
    end

    private def tool_from_opts!(opts)
      case opts
      when Hash
        tool = opts.delete(:_tool)
      when Array
        index = opts.find_index{ |k,v| k == :_tool }
        if index
          tool = opts[index].last
          opts.delete_at(index)
        end
      else
        raise ArgumentError,
          "opts must be Array or Hash but they are #{opts.inspect}"
      end

      if tool == "oc"
        tool = nil
      end
      return tool
    end

    # get `oc` version on some host running as some username
    # @param user [String] string username
    # @param host [BushSlicer::Host] the host to execute command on
    # @return [String] version string
    def self.get_version_for(user, host)
      fake_config = Tempfile.new("kubeconfig")
      fake_config.close

      res = host.exec_as(user, "oc version -o yaml --client --kubeconfig=#{fake_config.path}")

      fake_config.unlink

      raise "cannot execute on host #{host.hostname} as user '#{user}'" unless res[:success]
      parsed = YAML.load res[:stdout]
      version_str = parsed.dig("clientVersion", "gitVersion")
      raise "unknown version format, see log" unless version_str
      return version_str.sub(/^v/, "")
    end

    # try to map ocp and origin cli version to a comparable integer value
    # we may switch to `major.minor` rules versions in the future
    private def rules_version(str_version)
      v = str_version.split('.')

      # https://bugzilla.redhat.com/show_bug.cgi?id=1781909
      # OCP = 4.1 format `v4.1.10-201908061216+c8c05d4-dirty`, return version 4.1
      # OCP = 4.2 format `openshift-clients-4.2.2-201910250432`, return version 4.2
      # OCP = 4.3 format `openshift-clients-4.3-2-ge0666000`, return version 4.3
      major = v[0].split('openshift-clients-').last
      minor = v[1].split('-').first
      return [major, minor].join('.')
    end

    # prepare kube config according to parameters
    # @param user [APIAccessor]
    # @return
    private def config_setup(user:, executor:, opts: {})
      if user.env.is_admin?(user)
        api_endpoint_url = @opts[:admin_api_endpoint_url]
      else
        api_endpoint_url = user.env.api_endpoint_url
      end

      if user.token
        ## login with existing token
        res = executor.run(:login, token: user.token, server: api_endpoint_url, _timeout: LOGIN_TIMEOUT, **opts)
      elsif user.client_cert
        cert = nil
        key = nil
        Tempfile.create('clcert') do |f|
          f.binmode
          f.print user.client_cert.to_pem
          f.close
          cert = executor.host.absolutize(File.basename(f.path))
          executor.host.copy_to(f.path, cert)
        end
        Tempfile.create('clkey') do |f|
          f.binmode
          f.print user.client_key.to_pem
          f.close
          key = executor.host.absolutize(File.basename(f.path))
          executor.host.copy_to(f.path, key)
        end
        # must not match any popular project name like "default"
        # see https://bugzilla.redhat.com/show_bug.cgi?id=1642149
        default_context_name = "generated"
        # oc --config=/tmp/tmp.config --server=https://ec2-54-86-33-62.compute-1.amazonaws.com:443 --client-certificate=/tmp/crt --client-key=/tmp/key --insecure-skip-tls-verify=true get user '~' --template='{{.metadata.name}}'
        res = executor.run(:config_set_creds, name: user.id, cert: cert, key: key, embed: true, server: api_endpoint_url, **opts)
        raise "setting keys failed, see log" unless res[:success]
        res = executor.run(:config_set_cluster, name: "#{default_context_name}-cluster", server: api_endpoint_url, **opts)
        raise "setting cluster failed, see log" unless res[:success]
        res = executor.run(:config_set_context, name: default_context_name, cluster: "#{default_context_name}-cluster", user: user.id, **opts)
        raise "setting context failed, see log" unless res[:success]
        res = executor.run(:config_use_context, name: default_context_name, **opts)
        raise "using context failed, see log" unless res[:success]
      else
        raise "no idea how to prepare kubeconfig for api accessor without a " \
          "token or client certificate"
      end

      unless res[:success]
        logger.debug res[:instruction]
        raise "cannot login with command"
      end
    end

    # @return [String] the user auth token
    def self.token_from_cli(user: nil, executor: nil, opts: {})
      view_opts = { output: "yaml", minify: true, _timeout: LOGIN_TIMEOUT }
      if user
        res = user.cli_exec(:config_view, **view_opts)
      else
        res = executor.run(:config_view, **view_opts, **opts)
      end
      unless res[:success]
        user.env.master_hosts[0].logger.error res[:response]
        raise "cannot read user configuration by: #{res[:instruction]}"
      end
      conf = YAML.load(res[:response])
      # Characters like '+' can be ignored by oc. Picking the first user.
      # uhash = conf["users"].find{|u| u["name"].start_with?(user.name + "/")}
      return conf["users"][0]["user"]["token"]
    end

    # @return [Array, nil] an array of two elements, first is
    #   [OpenSSL::X509::Certificate] and second [OpenSSL::PKey::RSA], or nil
    #   when no certificate can be retrieved
    def self.client_cert_from_cli(user)
      res = user.cli_exec(:config_view, flatten: true, minify: true)
      unless res[:success]
        user.env.master_hosts[0].logger.error res[:response]
        raise "cannot read user configuration by: #{res[:instruction]}"
      end
      conf = YAML.load(res[:response])
      # uhash = conf["users"].find{|u| u["name"].start_with?(user.name + "/")}
      uhash = conf["users"].first # minify should show us only current user

      crt = uhash["user"]["client-certificate-data"]
      key = uhash["user"]["client-key-data"]
      return key ? [OpenSSL::X509::Certificate.new(Base64.decode64(crt)), OpenSSL::PKey::RSA.new(Base64.decode64(key))] : nil
    end

    def clean_up
      # Should we remove any cli configfiles here? only in subclass when that
      #   is safe! Also we should not logout, because we clean-up tokens
      #   in User class where care is taken to avoid removing protected tokens.
    end
  end

  # execute cli commands on the first master machine as each user respectively
  #   it also does prior cert and token setup
  # @deprecated Please use [SharedLocalCliExecutor] instead
  #   or another executor running on localhost. Remote excutors will fail for
  #   scenarios that run commands to read for local files
  class MasterOsPerUserCliExecutor < CliExecutor
    def initialize(env, **opts)
      super
      @executors = {}
    end

    # @param [BushSlicer::APIAccessor] api accessor to execute command with
    # @return rules executor, separate one per user
    private def executor(user, cli_tool: nil)
      executor_id = "#{cli_tool}:#{user}"
      return @executors[executor_id] if @executors[executor_id]

      host = user.env.api_host
      file_prefix = cli_tool ? "#{cli_tool}-" : nil
      os_user = user.id == "admin" ? :admin : user.id
      version = version_for_user(os_user, host)
      rules_file = "#{RULES_DIR}/#{file_prefix}#{rules_version(version)}.yaml"
      executor = RulesCommandExecutor.new(host: host, user: os_user, rules: File.expand_path(rules_file))

      if os_user != :admin && !cli_tool
        # we avoid touching root kubeconfig on master as much as possible
        config_setup(user: user, executor: executor, opts: {ca: "/etc/openshift/master/ca.crt"})
      end

      # this executor is ready to be used, set it early to allow caching token
      @executors[executor_id] = executor

      return executor
    end

    # @param user [String] the user we want to get version for
    # @param host [BushSlicer::Host] the host we'll be running commands on
    private def version_for_user(user, host)
      # we assume all users will use same oc version;
      #   we may revisit later if needed
      opts[:cli_version] ||= CliExecutor.get_version_for(user.name, host)
    end

    # see CliExecutor#exec
    def exec(user, key, opts={})
      cli_tool = tool_from_opts!(opts)
      executor(user, cli_tool: cli_tool).run(key, opts)
    end

    def clean_up
      # should we remove any cli configfiles here? maybe not..
      #   also we should not logout as we remove tokens in another manner
      #   and some tokens need to be protected to avoid losing them
      @executors.values.each(&:clean_up)
      @executors.clear
    end
  end

  class SharedLocalCliExecutor < CliExecutor
    attr_reader :host

    def initialize(env, **opts)
      super
      @host = localhost
      @logged_users = {}
      @executors = {}
    end

    # @return [RulesCommandExecutor] executor to run commands with
    private def executor(cli_tool: nil)
      return @executors[cli_tool] if @executors[cli_tool]

      file_prefix = cli_tool ? "#{cli_tool}-" : nil
      rules_file = "#{RULES_DIR}/#{file_prefix}#{rules_version(version)}.yaml"

      @executors[cli_tool] = RulesCommandExecutor.new(
        host: host,
        user: nil,
        rules: File.expand_path(rules_file)
      )
    end

    private def version
      opts[:cli_version] ||= CliExecutor.get_version_for(nil, localhost)
    end

    private def logged_users
      @logged_users
    end

    # clean-up .kube/config and .config/openshift/config
    #   we don't need this as long as we use the --config option
    #private def clean_old_config
    #  # this should also work on windows %USERPROFILE%/.kube
    #  host.delete('.kube', :r => true, :raw => true, :home => true)
    #  host.delete('.config/openshift', :r => true, :raw => true, :home => true)
    #end

    # current implementation is to run client commands with
    #   --config=<workdir>/<env key>_<user name>.kubeconfig to provide isolation
    #   between users running cli commands. Another option considered was
    #   --context=... but for this to work, we would have needed to execute
    #   a second cli command after any cli command to obtain last user context.
    #   And that has two issues - it is an overhead as well running simultaneous
    #   commands may cause race conditions.
    # @return [Hash] :config => "<workdir>/<env key>_<user name>.kubeconfig"
    private def user_opts(user)
      user_config = "#{user.env.opts[:key]}_#{user.id}.kubeconfig"
      user_config = host.absolute_path user_config # inside workdir
      host.delete user_config

      # TODO: we may consider obtaining server CA chain and configuring it in
      #   instead of setting insecure SSL
      opts = {config: user_config, skip_tls_verify: "true"}
      add_proxy_env_opt(user.env, opts)
      config_setup(user: user, executor: executor, opts: opts)

      # success, set opts early to allow caching token
      logged_users[user.id] = {config: user_config}
      return logged_users[user.id]
    end

    # see CliExecutor#exec
    def exec(user, key, opts={})
      unless logged_users[user.id]
        user_opts(user)
      end

      add_proxy_env_opt(user.env, opts)
      cli_tool = tool_from_opts!(opts)
      if CENSOR_LOGS.any? { |cmd| key.match?(cmd) }
        opts << [:_quiet, true]
      end
      executor(cli_tool: cli_tool).
        run(key, Common::Rules.merge_opts(logged_users[user.id], opts))
    end

    def clean_up
      @executors.values.each(&:clean_up)
      @executors.clear
      logged_users.clear
      # do not remove local kube/openshift config file, workdir should be
      #   cleaned automatically between scenarios
      # we do not logout, see {CliExecutor#clean_up}
    end
  end
end
