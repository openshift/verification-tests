require 'openshift/cluster_resource'

module BushSlicer
  # @note represents an OpenShift cluster resource about console
  class ConsoleCliDownloadConsoleOpenshiftIo < ClusterResource
    RESOURCE = 'consoleclidownloads.console.openshift.io'
  end
end