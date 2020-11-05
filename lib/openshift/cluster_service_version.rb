require 'openshift/project_resource'

module BushSlicer
  class ClusterServiceVersion < ProjectResource
    RESOURCE = "clusterserviceversions"

    # @return [BushSlicer::ResultHash] with :success depending on
    # status phase=Succeeded and reason=InstallSucceeded;
    def ready?(user: nil, quiet: false, cached: false)
      res = get(user: user, quiet: quiet)
      res[:success] = res[:parsed]["status"]["phase"] == "Succeeded" && res[:parsed]["status"]["reason"] == "InstallSucceeded" if res[:success]
      return res
    end
  end
end
