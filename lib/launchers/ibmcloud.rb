

lib_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end
require 'collections'
require 'common'
require 'cgi'

require "ibm_vpc"

module BushSlicer
  class IBMCloud
    include Common::Helper
    include CollectionsIncl
    attr_reader :config, :vpc, :regions
    attr_accessor :region

    def initialize(**opts)
      @config = conf[:services, opts.delete(:service_name) || :ibmcloud]
      authenticator = IbmVpc::Authenticators::IamAuthenticator.new(
        apikey: @config[:auth][:apikey]
      )
      @vpc = IbmVpc::VpcV1.new(authenticator: authenticator)
      @regions ||= vpc.list_regions.result['regions']
      if opts[:region]
        puts("Setting region to #{opts[:region]}...\n")
        region=(opts[:region])
      end
    end

    # @return Array of region hash
    # {"name"=>"us-south", "href"=>"https://us-south.iaas.cloud.ibm.com/v1/regions/us-south", "endpoint"=>"https://us-south.iaas.cloud.ibm.com", "status"=>"available"}
    def regions
      @regions ||= self.vpc.list_regions.result['regions']
    end

    # @return Hash containing region information
    def get_region(name)
      region_hash = self.regions.select {|r| r['name'] == name}.first
      raise "Unsupported region '#{name}" unless region_hash
      return region_hash
    end

    def set_region(reg_name)
      region_info = self.get_region(reg_name)
      self.vpc.service_url = region_info['endpoint'] + "/v1"
    end
    # @returns current region hash
    def current_region
      self.vpc.service_url
      self.regions.select {|r| r['endpoint'].start_with? self.vpc.service_url[0..-4]}.first
    end

    def instances
      start = nil
      instances = []
      loop do
        response = self.vpc.list_instances(start: start)
        instances += response.result["instances"]

        next_link = response.result.dig("next", "href")
        break if next_link.nil?

        start = CGI.parse(URI(next_link).query)["start"].first
      end
      return instances
    end

    def get_instances_by_status(status: 'running', region: nil)
      instances = self.instances
      if instances.count > 0
        insts = instances.select {|i| i['status'] == status }
        instances = insts
      end
      return instances
    end

    def instance_uptime(instance)
      ((Time.now.utc - Time.parse(instance['created_at'])) / (60 * 60)).round(2)
    end

  end
end

if __FILE__ == $0
  extend BushSlicer::Common::Helper
  ibm = BushSlicer::IBMCloud.new(region: 'eu-gb')
  insts2 = ibm.instances
  print inst2
end

