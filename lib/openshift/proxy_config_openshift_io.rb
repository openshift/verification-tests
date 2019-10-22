require 'openshift/cluster_resource'

module BushSlicer
  class ProxyConfigOpenshiftIo < ClusterResource
    RESOURCE = 'proxies.config.openshift.io'

    def httpproxy(user: nil, quiet: false, cached: true)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'httpProxy')
    end

    def httpsproxy(user: nil, quiet: false, cached: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      return rr.dig('spec', 'httpsProxy')
    end
  end
end
