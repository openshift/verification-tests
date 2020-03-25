#!/usr/bin/env ruby

lib_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
    $LOAD_PATH.unshift(lib_path)
end

require_relative 'openstack4'
require_relative 'openstack10'

module BushSlicer
  class OpenStack
    extend Common::Helper

    def initialize(*options)
      raise 'please use the `#instance` method to instantiate'
    end

    # @param service_name [String] the service name of this openstack instance
    #   to lookup in configuration
    private_class_method def self.default_opts(service_name)
      return  conf[:services, service_name.to_sym]
    end

    def self.instance(**options)
      service_name = options[:service_name] ||
                     ENV['OPENSTACK_SERVICE_NAME'] ||
                     'openstack_qeos10'
      opts = default_opts(service_name).merge options

      ## poor's man OSP version detection
      url = opts[:url].match(%r{(^https?://[-:.a-zA-Z0-9]+)(/.*)?$})&.to_a&.fetch(1)
      raise "cannot parse auth URL #{opts[:url].inspect}" unless url
      res = Http.get(url: url)
      if res[:exitstatus] == 300
        versions = JSON.parse(res[:response]).dig("versions","values")
        if !versions ||
          versions.any? {|v| v["status"] == "stable" && v["id"] == "v2.0"}
          clazz = OpenStack4
        else
          clazz = OpenStack10
        end
      else
        clazz = OpenStack4
      end

      return clazz.new(**options, service_name: service_name)
    end
  end
end

## Standalone test
if __FILE__ == $0
  extend BushSlicer::Common::Helper
  test_res = {}
  conf[:services].each do |name, service|
    if service[:cloud_type] == 'openstack' && service[:password]
      os = BushSlicer::OpenStack.instance(service_name: name)
      res = true
      test_res[name] = res
      begin
        os.launch_instances(names: ["test_terminate"])
        os.delete_instance "test_terminate"
        test_res[name] = false
      rescue => e
        test_res[name] = e
      end
    end
  end

  test_res.each do |name, res|
    puts "OpenStack instance #{name} failed: #{res}"
  end

  require 'pry'
  binding.pry
end
