require 'openshift/project_resource'

module BushSlicer
  class CatalogSource < ProjectResource
    RESOURCE = "catalogsources"

  	def ready?(user:, quiet: false, cached: false)
  		res = get(user: user, quiet: quiet)
  		res[:success] = res[:parsed]["status"]["connectionState"]["lastObservedState"] == "READY"
  		return res
  	end
  end
end
