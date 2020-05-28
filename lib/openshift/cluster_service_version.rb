require 'openshift/project_resource'

module BushSlicer
  class ClusterServiceVersion < ProjectResource
    RESOURCE = "clusterserviceversions"

    # @return [BushSlicer::ResultHash] with :success depending on 
    # status phase=Succeeded and reason=InstallSucceeded;
    def ready?(user:, quiet: false, cached: false)
    	res = get(user: user, quiet: quiet)
    	if res[:success]
    		res[:success] = 
    			res[:parsed]["status"]["phase"] == "Succeeded" && res[:parsed]["status"]["reason"] == "InstallSucceeded"
    	end
    	return res
    end
  end
end
