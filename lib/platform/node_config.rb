require 'yaml'

module BushSlicer
  module Platform
    # class to help operation over node-config.yaml file on the OpenShift nodes
    class NodeConfig
      def self.for(service)
        if service.host.file_exist?("/etc/origin/node/bootstrap-node-config.yaml")
          # in 3.10 we have a config map sync daemonset
          NodeConfigMapSyncConfig.new(service)
        else
          SimpleServiceYAMLConfig.new(
            service,
            "/etc/origin/node/node-config.yaml"
          )
        end
      end
    end
  end
end
