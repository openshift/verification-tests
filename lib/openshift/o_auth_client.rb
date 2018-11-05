module BushSlicer
  class OAuthClient < ClusterResource
    RESOURCE = "oauthclients"
    # pls refer https://github.com/openshift-qe/output_refrences/tree/master/oauthclient for output example

    def redirect_uris(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet)['redirectURIs']
    end

    def secret(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet)['secret']
    end

    def scope_restrictions(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet)['scopeRestrictions']
    end
  end
end
