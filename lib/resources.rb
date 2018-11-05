require "openshift/resource"
require "openshift/cluster_resource"
require "openshift/project_resource"
require "openshift/pod_replicator"

module BushSlicer
  RESOURCES = {}

  Dir["#{File.dirname(__FILE__)}/openshift/*.rb"].each_entry do |file|
    snake_case_class = File.basename(file, ".rb").freeze
    require "openshift/#{snake_case_class}"
    camel_case_class = Common::BaseHelperStatic.snake_to_camel_case(snake_case_class).freeze
    clazz = Object.const_get("::BushSlicer::#{camel_case_class}")
    if defined? clazz::RESOURCE
      RESOURCES[clazz] = snake_case_class.to_sym
    end
  end

  RESOURCES.freeze
end
