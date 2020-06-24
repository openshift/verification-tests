require 'yaml'
require 'common'
require 'openshift/cluster_resource'

module BushSlicer
  class ImageContentSourcePolicy < ClusterResource
    RESOURCE = 'imagecontentsourcepolicy'

    def mirror_repository(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig("spec", 'repositoryDigestMirrors')[0]['mirrors']
    end

    def mirror_registry(user)
      return self.mirror_repository(user).join.match(/[^\/]*\//)[0]
    end
  end
end
