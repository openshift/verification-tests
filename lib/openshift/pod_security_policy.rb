require 'openshift/cluster_resource'

module BushSlicer
  class PodSecurityPolicy < ClusterResource
    RESOURCE = 'podsecuritypolicies'

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> same should return true)
    def status_reachable?(from_status, to_status)
      raise "status not applicable to PodSecurityPolicies"
    end
  end
end
