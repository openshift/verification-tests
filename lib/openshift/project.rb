require 'yaml'

require_relative 'build'
require_relative 'cluster_resource'
require_relative 'pod'
require_relative 'role_binding'

module BushSlicer
  # @note represents an OpenShift environment project
  class Project < ClusterResource
    RESOURCE = "projects".freeze
    SYSTEM_PROJECTS = [ "openshift-infra".freeze,
                        "default".freeze,
                        "management-infra".freeze,
                        "openshift".freeze ]

    # @override
    def visible?(user: nil, result: {}, quiet: false)
      result.clear.merge!(get(user: user, quiet: quiet))
      if result[:success]
        return true
      else
        case  result[:response]
        when /Error from server \(Forbidden\)/, /Error from server \(NotFound\)/
          return false
        else
          raise "error getting project '#{name}' existence: #{result[:response]}"
        end
      end
    end
    alias exists? visible?

    def empty?(user: nil)
      res = default_user(user).cli_exec(:status, suggest: true, n: name)

      res[:success] = res[:response] =~ /ou have no.+services.+deployment.+configs/
      return res
    end

    # @note call without parameters only when props are loaded
    # @return a Ruby Range object i.e. the API returns a string 10120000/1000, string transformed into a ruby Range object
    def uid_range(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      range_string = rr.dig('metadata', 'annotations', 'openshift.io/sa.scc.uid-range')
      uids = range_string.split('/').map { |n| Integer(n) }
      uid_range = (uids[0]...uids[0] + uids[1])
      return uid_range
    end

    # scc's mcs (https://www.centos.org/docs/5/html/Deployment_Guide-en-US/sec-mcs-ov.html)
    def mcs(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('metadata', 'annotations', 'openshift.io/sa.scc.mcs')
    end

    # @return a Ruby Range object i.e. the API returns a string 10120000/1000, string transformed into a ruby Range object
    def supplemental_groups(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      range_string = rr.dig('metadata', 'annotations', 'openshift.io/sa.scc.supplemental-groups')
      groups = range_string.split('/').map { |n| Integer(n) }
      group_range = (groups[0]...groups[0] + groups[1])
      return group_range
    end

    # @return [Hash<String, String>] of node selector if specified
    def defined_node_selector(user: nil, cached: true, quiet: false)
      annotation("openshift.io/node-selector",
                 user: user, cached: cached, quiet: quiet)&.
                split(",")&.
                map { |l| l.split("=") }&.
                to_h
    end

    # creates a new project
    # @param by [BushSlicer::APIAccessorOwner, BushSlicer::APIAccessor] the user to create project as
    # @param name [String] the name of the project
    # @return [BushSlicer::ResultHash]
    def self.create(by:, name: nil, **opts)
      if name
        res = self.new(name: name, env: by.env).create(by: by, **opts)
        res[:resource] = res[:project]
      else
        res = super(by: by, **opts)
        res[:project] = res[:resource]
      end
      return res
    end

    def active?(user: nil, cached: false)
      phase(user: user, cached: cached) == :active
    end

    # creates project as defined in this object
    def create(by:, **opts)
      # note that search for users is only done inside the set of users
      #   currently used by scenario; we don't expect scenario to know
      #   usernames before a user is actually requested from the user_manager
      if env.is_admin?(by) &&
             ! env.users.by_name(opts[:admin]) &&
             ! opts.delete(:clean_up_registered)
        raise "creating project as admin without administrators may easily lead to project leaks in the test framework, avoid doing so"
      elsif opts.delete(:_via) == :web
        res = by.webconsole_exec(:new_project, project_name: name, **opts)
      else
        res = by.cli_exec(:new_project, project_name: name, **opts)
      end
      started_at = Time.now
      success = wait_for(60, interval: 5) {
        uid_range = by.cli_exec(:get, resource: "namespace", resource_name: name, template: '{{ index .metadata.annotations "openshift.io/sa.scc.uid-range" }}')
        !uid_range.nil? && !uid_range.empty? && uid_range.to_s !~ /no value/
      }
      wait_since = Time.now - started_at
      unless success
        raise "timeout waiting for project #{name} to get annotation openshift.io/sa.scc.uid-range after #{wait_since} seconds, consider reporting a bug"
      end
      res[:project] = self
      return res
    end

    def is_user_admin?(user: nil, cached: true, quiet: false)
      user ||= default_user(user)
      unless cached && @is_admin_hash&.has_key?(user)
        @is_admin_hash ||= {}
        if env.version_ge("3.3", user: user)
          res = user.cli_exec(:auth_can_i,
                              verb: "delete",
                              resource: "project",
                              n: self.name,
                              q: true,
                              _quiet: quiet)
          # note that without quiet option, exit code is always 0
          # oc auth can-i always returns non-zero for "no" though
          @is_admin_hash[user] = res[:success]
        else
          fakeuser = rand_str(8, :dns952)
          res = user.cli_exec(:policy_add_role_to_user,
                              role: "admin",
                              n: self.name,
                              user_name: fakeuser,
                              _quiet: quiet)
          @is_admin_hash[user] = res[:success]
          if res[:success]
            res = user.cli_exec(:policy_remove_role_from_user,
                                role: "admin",
                                n: self.name,
                                user_name: fakeuser,
                                _quiet: quiet)
            unless res[:success]
              logger.warn "role admin could not be removed from fake user: " \
                "#{fakeuser}"
            end
          end
        end
      end
      return @is_admin_hash[user]
    end

    ############### related to objects owned by this project ###############
    def get_pods(by:, **get_opts)
      Pod.list(user: by, project: self, **get_opts)
    end
    alias_method :pods, :get_pods

    def jobs(by:, **get_opts)
      Job.list(user: by, project: self, **get_opts)
    end

    def get_builds(by:, **get_opts)
      Build.list(user: by, project: self, **get_opts)
    end

    #oc delete all -l app=hi -n ie2yc
    #buildconfigs/ruby-hello-world
    #builds/ruby-hello-world-1
    #imagestreams/mysql-55-centos7
    #imagestreams/ruby-20-centos7
    #imagestreams/ruby-hello-world
    #deploymentconfigs/mysql-55-centos7
    #deploymentconfigs/ruby-hello-world
    #services/mysql-55-centos7
    #services/ruby-hello-world
    # @param labels [String, Array<String,String>, read carefully description of
    #   [BushSlicer::Common::BaseHelper#selector_to_label_arr]
    # @param by [User] the user to execute operation with
    # @param cmd_opts [**Hash] command line options overrides
    def delete_all_labeled(*labels, by:, **cmd_opts)
      default_opts = {
        object_type: :all,
        l: selector_to_label_arr(*labels),
        n: name
      }
      opts = default_opts.merge cmd_opts

      return default_user(by).cli_exec(:delete, **opts)
    end
  end
end
