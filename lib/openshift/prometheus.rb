require 'openshift/project_resource'

module BushSlicer
  class Prometheus < ProjectResource
    RESOURCE = "prometheuses.monitoring.coreos.com"

    def enforced_sample_limit(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig("spec", "enforcedSampleLimit")
    end

    def log_level(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig("spec", "logLevel")
    end

    def retention(user: nil, cached: true, quiet: true)
      raw_resource(user: user, cached: cached, quiet: quiet).dig("spec", "retention")
    end
    
  end
end
