require 'openshift/project_resource'

module BushSlicer
  class ClusterServiceVersion < ProjectResource
    RESOURCE = "clusterserviceversions"
  def ready?(user: nil, quiet: false, cached: false)
      if cached && props[:raw]
        res = { instruction: "get cached clusterserviceversion #{name} readiness",
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
            c["phase"] == "Succeeded" && c["reason"] == "InstallSucceeded"
          }
      end
      return res
    end
  end
end
