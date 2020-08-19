require 'openshift/cluster_resource'

module BushSlicer
  class ValidatingWebhookConfiguration < ClusterResource
    RESOURCE = "ValidatingWebhookConfiguration"
  end
end