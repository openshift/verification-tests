require 'openshift/project_resource'
require 'openshift/quota_limits'

module VerificationTests
  class ResourceQuota < ProjectResource
    RESOURCE = 'resourcequotas'

    def hard_quota(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      quota =  rr.dig("spec", "hard")

      return QuotaLimits.new(quota)
    end

    def total_used(user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      quota =  rr.dig("status", "used")

      return QuotaLimits.new(quota)
    end

    # @return [QuotaLimits] quota for specified storage class
    def sc_used(name: nil, user: nil, cached: true, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet)
      ru =  rr.dig("status", "used")
      quota = {}
      ru.each do |key, value|
        if key.include?("#{name}.storageclass.storage.k8s.io")
          qk = key.split("/")[1]
          quota[qk] = value
        end
      end

      return QuotaLimits.new(quota)
    end
  end
end
