require 'openshift/project_resource'
require 'openshift/quota_limits'

module BushSlicer
  # @note represents an OpenShift applied cluster resource quota
  class AppliedClusterResourceQuota < ProjectResource
    RESOURCE = 'appliedclusterresourcequotas'

    def total_used(user: nil, cached: true, quiet: false)
      quota = raw_resource(user: user, cached: cached, quiet: quiet).
        dig("status", "total", "used")
      return QuotaLimits.new(quota)
    end

    # should we read this from spec or status total?
    def hard_quota(user: nil, cached: true, quiet: false)
      quota = raw_resource(user: user, cached: cached, quiet: quiet).
        dig("spec", "quota", "hard")
      return QuotaLimits.new(quota)
    end
  end
end
