module VerificationTests
  class PVCPodVolumeSpec < PodVolumeSpec
    TYPE = "persistentVolumeClaim"

    def claim
      @claim ||= PersistentVolumeClaim.new(
                   name: raw[TYPE]["claimName"],
                   project: owner.project
                 )
    end
  end
end
