require 'openshift/cluster_resource'

module VerificationTests
  # @note represents an OpenShift environment Persistent Volume
  class PersistentVolume < ClusterResource
    STATUSES = [:available, :bound, :pending, :released, :failed]
    RESOURCE = 'persistentvolumes'

    # @param from_status [Symbol] the status we currently see
    # @param to_status [Array, Symbol] the status(es) we check whether current
    #   status can change to
    # @return [Boolean] true if it is possible to transition between the
    #   specified statuses (same -> same should return true)
    def status_reachable?(from_status, to_status)
      [to_status].flatten.include?(from_status) ||
        ![:failed].include?(from_status)
    end

    def reclaim_policy(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", 'persistentVolumeReclaimPolicy')
    end

    def volume_mode(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", 'volumeMode')
    end

    def storage_class_name(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", 'storageClassName')
    end

    def claim_ref(user: nil, cached: true, quiet: false)
      unless cached && props.has_key?(:claim)
        raw =raw_resource(user: user, cached: cached, quiet: quiet).dig(
          "spec", "claimRef"
        )
        props[:claim] = raw.nil? ? nil : ObjectReference.new(raw)
      end
      return props[:claim]
    end

    def claim(user: nil, cached: true, quiet: false)
      claim_ref(user: user, cached: cached, quiet: quiet)&.resource(self)

      # docs state that authoritative bind is PCV->volume_name
      # so we may need this code in case `claim_ref` turns out unreliable
      # https://docs.okd.io/latest/rest_api/api/v1.PersistentVolume.html#object-schema
      # props[:pvc] = PersistentVolumeClaim.list(user: default_user(user), project: :all) { |pvc, hash|
      #   name == pvc.volume_name(user: default_user(user), cached: cached, quiet: quiet)
      # }.first
    end

    private def delete_deps(user: nil, cached: false, quiet: false)
      protection = finalizers(user: user, cached: cached, quiet: quiet)&.
        include? "kubernetes.io/pv-protection"
      if protection && phase(user: user, cached: true, quiet: quiet) == :bound
        [ claim(cached: true) ]
      else
        []
      end
    end

    def finalizers(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig('metadata', 'finalizers')
    end

    def deletion_timestamp(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      rr.dig("metadata", "deletionTimestamp")
    end

    def capacity_raw(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('spec', 'capacity', 'storage')
    end

    def local_path(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).
        dig('spec', 'local', 'path')
    end
  end
end
