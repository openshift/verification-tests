require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift cluster resource about console
  class ConsoleCliDownload < ClusterResource
    RESOURCE = 'consoleclidownload'
  end
end