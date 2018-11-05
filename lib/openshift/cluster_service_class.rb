require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Cluster Service Class
  class ClusterServiceClass < ClusterResource
    RESOURCE = "clusterserviceclasses"

    def metadata(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr['metadata']
    end

    def spec(spec: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr['spec']
    end

    def external_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig("spec", "externalName")
    end

    def dependencies(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'externalMetadata', 'dependencies')
    end

    def provider_display_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'externalMetadata', 'providerDisplayName')
    end

    # @return [Array<ClusterServicePlan>]
    def plans(user: nil, cached: true)
      unless cached && props[:plans]
        props[:plans] = ClusterServicePlan.list(user: default_user(user)) { |csp, hash|
          csp.cluster_service_class == self
        }
      end
      return props[:plans]
    end

    # @return [BushSlicer::ResultHash] with :success depending on
    #   condition type=Ready and status=True
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached clusterserviceclass #{name} readiness",
                response: props[:raw].to_yaml,
                success: true,
                exitstatus: 0,
                parsed: props[:raw]
        }
      else
        res = get(user: user, quiet: quiet)
      end
      if res[:success]
        res[:success] =
          res[:parsed]["status"] &&
          res[:parsed]["status"]["conditions"] &&
          res[:parsed]["status"]["conditions"].any? { |c|
            c["type"] == "Ready" && c["status"] == "True"
          }
      end
      return res
      
    end
  end  # end of class
end
