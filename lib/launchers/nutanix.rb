lib_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end

require 'collections'
require 'common'

module BushSlicer
  class Nutanix
    include Common::Helper
    include CollectionsIncl
    attr_reader :config

    def initialize(**opts)
      service_name = opts.delete(:service_name)
      if service_name
        @config = conf[:services, service_name]
      else
        @config = {}
      end

      config_opts = opts.delete(:config)
      if config_opts
        deep_merge!(@config, config_opts)
      end
    end
  end
end
