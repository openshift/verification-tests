require 'openshift/cluster_resource'

module BushSlicer
  class ValidatingWebhookConfiguration < ClusterResource
    RESOURCE = "validatingwebhookconfigurations.admissionregistration.k8s.io"

    def output_to_ref(user: nil, cached: true, quiet: false)
      unless cached && props[:output_to_ref]
        raw = raw_resource(user: user, cached: cached, quiet: quiet)
        props[:output_to_ref] = ObjectReference.new(raw)
      end
      return props[:output_to_ref]
    end

    def output_to(user: nil, cached: true, quiet: false)
      output_to_ref(user: user, cached: cached, quiet: quiet).resource(self)
    end
  end
end