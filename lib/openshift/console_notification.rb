require 'openshift/cluster_resource'

module BushSlicer
  class ConsoleNotification < ClusterResource
    RESOURCE = "consolenotification.console.openshift.io"
  end
end
