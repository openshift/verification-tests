require 'openshift/project_resource'

module BushSlicer
  class Prometheus < ProjectResource
    RESOURCE = "prometheuses.monitoring.coreos.com"

    def enforced_sample_limit(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig("spec", "enforcedSampleLimit")
    end
    
  end
end
