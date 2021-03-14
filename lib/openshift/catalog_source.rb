require 'openshift/project_resource'

module BushSlicer
  class CatalogSource < ProjectResource
    RESOURCE = "catalogsources"

  	def ready?(user:, quiet: false, cached: false)
  		res = get(user: user, quiet: quiet)
  		res[:success] = res[:parsed]["status"]["connectionState"]["lastObservedState"] == "READY"
  		return res
  	end

  	def endpoint(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'image')
  	end

  	def registrypollinterval(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr['spec'].has_key?('updateStrategy') ? rr.dig('spec', 'updateStrategy', 'registryPoll', 'interval') : '-'	
  	end

  	def publisher(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr['spec'].has_key?('publisher') ? rr.dig('spec', 'publisher') : '-'	
  	end

  	def status(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('status', 'connectionState', 'lastObservedState')  		
  	end

  	def displayname(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr['spec'].has_key?('displayName') ? rr.dig('spec', 'displayName') : '-'
  	end
  end
end
