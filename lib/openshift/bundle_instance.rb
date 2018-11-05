module BushSlicer

  class BundleInstance < ProjectResource
    RESOURCE = "bundleinstances"
    # return binding ids 
    def bundle_binding_ids(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'bindings')
    end

  end
end
