require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift cluster resource about console
  class ConsolePlugin < ClusterResource
    RESOURCE = 'consoleplugin'
  end
end