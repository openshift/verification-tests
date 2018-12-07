require 'openshift/cluster_resource'

module VerificationTests
  # @note represents an OpenShift environment Cluster Service Plan
  class ClusterServicePlan < ClusterResource
    RESOURCE = "clusterserviceplans"

    def external_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig("spec", "externalName")
    end

    def cluster_service_class(user: nil, cached: true, quiet: false)
      unless cached && props[:csc]
        rr = raw_resource(user: user, cached: cached, quiet: quiet)
        props[:csc] = ClusterServiceClass.new(
          name: rr.dig("spec", "clusterServiceClassRef", "name"),
          env: env
        )
      end
      return props[:csc]
    end
  end
end
