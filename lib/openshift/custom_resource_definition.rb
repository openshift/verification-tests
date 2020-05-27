require 'openshift/project_resource'

module BushSlicer
  class CustomResourceDefinition < ClusterResource
    RESOURCE = "customresourcedefinitions"

    # @return [BushSlicer::ResultHash] with :success depending on 
    # status phase=Succeeded and reason=InstallSucceeded;
    def ready?(user:, quiet: false, cached: false)
      res = get(user: user, quiet: quiet)
      if res[:success]
        res[:success] =
          res[:parsed]["status"] &&
          res[:parsed]["status"]["conditions"] &&
          res[:parsed]["status"]["conditions"].any? { |c|
            c["type"] == "Established" && c["status"] == "True"
          }
      end
      return res
    end
  end
end
