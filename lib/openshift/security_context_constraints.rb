require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Persistent Volume
  class SecurityContextConstraints < ClusterResource
    RESOURCE = 'securitycontextconstraints'

    def update_from_api_object(hash)
      super

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
      raise "status not applicable to SecurityContextConstraint"
    end
  end
end
