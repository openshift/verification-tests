module BushSlicer

  class BundleBinding < ProjectResource
    RESOURCE = "bundlebindings"

    def bundle_instance_id(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'bundleInstance')
    end

  end
end