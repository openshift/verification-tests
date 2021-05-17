require 'openshift/cluster_resource'

module BushSlicer
  class Profile < ClusterResource
    RESOURCE = 'profiles'

    def tuned_profile(user: nil, cached: true, quiet: false)
      profile = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'config', 'tunedProfile')
      return profile
    end

  end
end
