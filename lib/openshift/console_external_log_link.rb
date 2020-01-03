require 'openshift/cluster_resource'

module BushSlicer
  class ConsoleExternalLogLink < ClusterResource
    RESOURCE = "consoleexternalloglinks.console.openshift.io"
  end
end

