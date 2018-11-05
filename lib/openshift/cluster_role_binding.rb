require 'openshift/cluster_resource'
require 'openshift/flakes/unknown_role_binding_subject'

module BushSlicer
  # @note represents an OpenShift environment Persistent Volume
  class ClusterRoleBinding < ClusterResource
    RESOURCE = 'clusterrolebindings'

    # @return [Array<String>]
    def user_names(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet)["userNames"]
    end

    def role(user: nil, cached: true, quiet: false)
      unless cached && props[:role]
        role = raw_resource(user: user, cached: cached, quiet: quiet).
          dig("roleRef", "name")
        props[:role] = ClusterRole.new(name: role, env: env)
      end
      return props[:role]
    end

    # @return [Array<User, Group, ServiceAccount, Systemuser, SystemGroup>]
    def subjects(user: nil, cached: true, quiet: false)
      unless cached && props[:subjects]
        rbs = raw_resource(user: user, cached: cached, quiet: quiet)["subjects"]
        props[:subjects] = rbs.map { |rb|
          case rb["kind"]
          when "SystemUser", "SystemGroup", "User", "Group"
            Object.const_get("::BushSlicer::#{rb['kind']}")
              .new(name: rb["name"], env: env)
          when "ServiceAccount"
            ServiceAccount.new(
              name: rb["name"],
              project: Project.new(name: rb["namespace"], env: env)
            )
          else
            logger.warn("ClusterRoleBinding #{name.inspect} has unknown " \
                        "subject kind #{rb["name"].inspect}")
            UnknownRoleBindingSubject.new
          end
        }
      end
      return props[:subjects]
    end

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> same should return true)
    def status_reachable?(from_status, to_status)
      raise "status not applicable to ClusterRoleBinding"
    end
  end
end
