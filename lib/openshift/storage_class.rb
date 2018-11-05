require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift environment Storage Class
  class StorageClass < ClusterResource
    RESOURCE = "storageclasses"

    def default?(user: nil, cached: true, quiet:false)
      opts = { user: user, cached: cached, quiet: quiet }
      default_annotation_value =
        annotation("storageclass.kubernetes.io/is-default-class", **opts) ||
        annotation("storageclass.beta.kubernetes.io/is-default-class")
      return "true" == default_annotation_value
    end

    def provisioner(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('provisioner')
    end

    def rest_url(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('parameters', 'resturl')
    end

    def monitors(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('parameters', 'monitors')
    end
  end
end
