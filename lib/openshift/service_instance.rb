module VerificationTests
  # represents an OpenShift ConfigMap
  class ServiceInstance < ProjectResource
    RESOURCE = "serviceinstances"

    def generation(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('metadata', 'generation')
    end

    def external_id(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'externalID')
    end

    def cluster_service_class_external_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'clusterServiceClassExternalName')
    end

    def cluster_service_class_ref(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'clusterServiceClassRef')
    end

    # @return [VerificationTests::ResultHash] with :success depending on
    #   condition type=Ready and status=True
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached service instance #{name} readiness",
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
