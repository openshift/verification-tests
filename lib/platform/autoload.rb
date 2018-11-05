module BushSlicer
  module Platform
    autoload :OpenShiftService, "platform/openshift_service"
    autoload :MasterService, "platform/master_service"
    autoload :MasterScriptedStaticPodService, "platform/master_scripted_static_pod_service.rb"
    autoload :MasterSystemdService, "platform/master_systemd_service.rb"
    autoload :NodeService, "platform/node_service"
    autoload :MasterConfig, "platform/master_config"
    autoload :NodeConfig, "platform/node_config"
    autoload :AggregationService, "platform/aggregation_service"
    autoload :SystemdService, "platform/systemd_service"
    autoload :ScriptService, "platform/script_service"
    autoload :RestorableFile, "platform/restorable_file"
    autoload :YAMLRestorableFile, "platform/yaml_restorable_file"
    autoload :SimpleServiceYAMLConfig, "platform/simple_service_yaml_config"
    autoload :NodeConfigMapSyncConfig, "platform/node_config_map_sync_config"
  end
end
