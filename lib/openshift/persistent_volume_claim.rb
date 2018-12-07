require 'openshift/project_resource'

module VerificationTests
  # represents an OpenShift PersistentVolumeClaim (pvc for short)
  class PersistentVolumeClaim < ProjectResource
    STATUSES = [:bound, :failed, :pending, :lost, :terminating]
    RESOURCE = "persistentvolumeclaims"

    # cache some usualy immutable properties for later fast use; do not cache
    #   things that can change at any time like status and spec
    def update_from_api_object(dc_hash)
      super

      props[:metadata] = m = dc_hash["metadata"]
      s = dc_hash["spec"]
      props[:labels] = m["labels"]
      props[:created] = m["creationTimestamp"] # already [Time]
      props[:spec] = s
      props[:status] = dc_hash["status"] # for brave and stupid people

      return self # mainly to help ::from_api_object
    end

    # @return [VerificationTests::ResultHash] with :success if status is Bound
    def ready?(user: nil, quiet: false, cached: false)
      status?(user: user, status: :bound, quiet: quiet, cached: cached)
    end

    def volume_name(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'volumeName')
    end

    def volume_mode(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('spec', 'volumeMode')
    end

    def capacity(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      # I guess would be nil when not bound
      rr.dig('status', 'capacity', 'storage')
    end

    def access_modes(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('status', 'accessModes')
    end

    def storage_class(user: nil, cached: true, quiet: false)
      metadata = get_cached_prop(prop: :metadata, user: user, cached: cached, quiet: quiet)
      spec = get_cached_prop(prop: :spec, user: user, cached: true, quiet: quiet)
      # From some weird reason, beta annotations take precedence over "stable" ones in Kubernetes.
      # https://bugzilla.redhat.com/show_bug.cgi?id=1448385#c1
      return metadata.dig('annotations', 'volume.beta.kubernetes.io/storage-class') || \
             metadata.dig('annotations', 'volume.kubernetes.io/storage-class')      || \
             spec['storageClassName']
    end

    def finalizers(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('metadata', 'finalizers')
    end

    def deletion_timestamp(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig("metadata", "deletionTimestamp")
    end

    # @return [Array<Pod>]
    def claiming_pods(user: nil, cached: true, quiet: false)
      unless cached && props[:claiming_pods]
        props[:claiming_pods] =
          Pod.list(user: default_user(user), project: project) { |pod, hash|
          pod.volume_claims(cached: true).include? self
        }
      end
      return props[:claiming_pods]
    end

    private def delete_deps(user: nil, cached: false, quiet: false)
      protection = finalizers(user: user, cached: cached, quiet: quiet)&.
        include? "kubernetes.io/pvc-protection"
      if protection && phase(user: user, cached: true, quiet: quiet) == :bound
        claiming_pods(cached: true)
      else
        []
      end
    end
  end
end
