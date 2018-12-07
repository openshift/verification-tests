require 'openshift/cluster_resource'

module VerificationTests
  # @note represents an OpenShift environment Cluster Service Broker
  class ClusterServiceBroker < ClusterResource
    RESOURCE = "clusterservicebrokers"
    def metadata(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr['metadata']
    end

    def spec(spec: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr['spec']
    end

    def relist_behavior(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig("spec", "relistBehavior")
    end

    def relist_duration_raw(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig("spec", "relistDuration")
    end

    def relist_requests(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig("spec", "relistRequests")
    end

    def url(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig("spec", "url")
    end

    # @return [VerificationTests::ResultHash] with :success depending on
    #   condition type=Ready and status=True
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached clusterservicebroker #{name} readiness",
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
    
  end
end
