require 'openshift/cluster_resource'

require_relative 'flakes/policy_rule'

module VerificationTests
  # @note represents an OpenShift environment Persistent Volume
  class ClusterRole < ClusterResource
    RESOURCE = 'clusterroles'

    def update_from_api_object(hash)
      super

      m = hash["metadata"]

      unless hash["kind"] == shortclass
        raise "hash not from a #{shortclass}: #{hash["kind"]}"
      end
      unless name == m["name"]
        raise "hash from a different #{shortclass}: #{name} vs #{m["name"]}"
      end

      props[:role_ref] = hash["roleRef"]
      props[:subjects] = hash["subjects"]
      props[:user_names] = hash["userNames"]

      return self # mainly to help ::from_api_object
    end

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> same should return true)
    def status_reachable?(from_status, to_status)
      raise "status not applicable to ClusterRole"
    end

    def rules(user: nil, cached: true, quiet: false)
      unless cached && props[:rules]
        props[:rules] = raw_resource(user: user, cached: cached, quiet: quiet).dig("rules").map { |s|
          PolicyRule.new(s, self)
        }
      end
      return props[:rules]
    end
  end
end
