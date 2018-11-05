require 'openshift/project_resource'

module BushSlicer
  # represents an OpenShift ReplicationController (rc for short) used for scaling pods
  class Job < ProjectResource
    RESOURCE = "jobs"

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change at any time like status and spec
    def update_from_api_object(rc_hash)
      m = rc_hash["metadata"]
      s = rc_hash["spec"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:spec] = s
      props[:status] = rc_hash["status"] # may change, use with care

      return self # mainly to help ::from_api_object
    end

    # @return [BushSlicer::ResultHash] with :success depending on
    #   status['replicas'] == spec['replicas']
    # @note we also need to check that the spec.replicas is > 0
    def ready?(user:, quiet: false, cached: false)
      if cached && props[:status] && props[:spec]
        cache = {
          "status" => props[:status],
          "spec" => props[:spec],
          "metadata" => {"name" => name}
        }

        res = {
          success: true,
          instruction: "get job #{name} cached ready status",
          response: cache.to_yaml,
          parsed: cache
        }
      else
        res = get(user: user, quiet: quiet)
        return res unless res[:success]
      end
      res[:success] = parallelism(cached: true) == succeeded(cached: true) &&
        status_conditions(cached: true).any? { |c|
          c["type"] == "Complete" && c["status"] == "True"
      }
      return res
    end
    alias succeeded? ready?

    def parallelism(user: nil, cached: true, quiet: false)
      spec = get_cached_prop(prop: :spec, user: user, cached: cached, quiet: quiet)
      return spec['parallelism']
    end

    def succeeded(user: nil, cached: false, quiet: false)
      status = get_cached_prop(prop: :status, user: user, cached: cached, quiet: quiet)
      return status['succeeded']
    end

    def status_conditions(user: nil, cached: false, quiet: false)
      status = get_cached_prop(prop: :status, user: user, cached: cached, quiet: quiet)
      return status['conditions']
    end
  end
end
