# represent a clusterlogforwarder object
require 'openshift/cluster_resource'

module BushSlicer
  class ClusterLogForwarder < ClusterResource
    RESOURCE = "clusterlogforwarders"
    
    def spec_raw(user: nil, quiet: false, cached: true)
        return raw_resource(user: user, cached: cached, quiet: quiet).dig('spec')
    end

    def outputs(user: nil, quiet: false, cached: true)
        return spec_raw(user: user, cached: cached, quiet: quiet).dig('outputs')
    end

    def output(user: nil, name:, quiet: false, cached: true)
        output = nil
        outputs = self.outputs(user: user, cached: cached, quiet: quiet)
        outputs.each do | o |
            output = o if o['name'] == name
        end
        return output
    end

    def pipelines(user: nil, quiet: false, cached: true)
        return spec_raw(user: user, cached: cached, quiet: quiet).dig('pipelines')
    end

    def pipeline(user: nil, name:, quiet: false, cached: true)
        pipeline = nil
        pipelines = self.pipelines(user: user, cached: cached, quiet: quiet)
        pipelines.each do | p |
            pipeline = p if p['name'] == name
        end
        return pipeline
    end

    def input_refs(user: nil, name:, quiet: false, cached: true)
        return pipeline(user: user, name: name, quiet: quiet, cached: cached).dig('inputRefs')
    end

    def output_refs(user: nil, name:, quiet: false, cached: true)
        return pipeline(user: user, name: name, quiet: quiet, cached: cached).dig('outputRefs')
    end

    def output_labels(user: nil, name:, quiet: false, cached: true)
        return pipeline(user: user, name: name, quiet: quiet, cached: cached).dig('labels')
    end

    def input_ref_names(user: nil, logtype:, quiet: false, cached: true)
        input_ref_names = []
        pipelines = self.pipelines(user: user, cached: cached, quiet: quiet)
        pipelines.each do | p |
            input_ref_names << p['name'] if p['inputRefs'].include?(logtype)
        end
        return input_ref_names
    end

    def status_raw(user: nil, quiet: false, cached: true)
        return raw_resource(user: user, cached: cached, quiet: quiet).dig('status')
    end


  end
end