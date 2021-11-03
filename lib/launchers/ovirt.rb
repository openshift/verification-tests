#!/usr/bin/env ruby
require 'ovirtsdk4'

require 'common'
require 'host'
require 'launchers/cloud_helper'

module BushSlicer

  class Ovirt
    include Common::Helper
    include Common::CloudHelper

    attr_reader :config
    attr_reader :trusted_ca_path
    attr_reader :ovirt_creds

    def initialize(**opts)
      @can_terminate = true
      service_name = opts[:service_name]
      if service_name
        @config = conf[:services, service_name]
      else
        @config ||= :OVIRT
      end
      config_opts = opts[:config]
      if config_opts
        deep_merge!(@config, config_opts)
      end

      @pem_url = @config[:api_url].gsub(/\/api\/?$/,"/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA")

      ca_path = @config[:ovirt_ca_file]
      @trusted_ca_path = trust_ovirt_certificate(ca_path)
      @ovirt_creds = generate_ovirt_creds(trusted_ca_path)
      @connection = OvirtSDK4::Connection.new(
          url: @config[:api_url],
          username: @config[:userdomain],
          password: @config[:password],
          insecure: @config[:insecure],
          ca_file:  @trusted_ca_path
      )
    end

    def get_resource(service, query=nil)
      error_msg =  "No resource '#{service}' found, please recheck the resouce you are looking for"
      svc = @connection.system_service.send("#{service}_service")
      if query
        resource_list = svc.list(search: query)
        if resource_list.length == 0
          raise error_msg
        end
        return resource_list
      else
        resource_list = svc.list
        if resource_list.length == 0
          raise error_msg
        end
        return resource_list
      end
    end

    def get_cluster_id(name)
      cluster = get_resource(service='clusters', query="name=#{name}")[0]
      return cluster.id
    end

    def get_storage_domain_id(name, cluster_name)
      cluster = get_resource(service='clusters', query="name=#{cluster_name}")[0]
      dc = @connection.follow_link(cluster.data_center)

      sd = self.get_resource(service='storage_domains', query="name=#{name} AND datacenter=#{dc.name}")[0]
      return sd.id
    end

    def get_vnic_profile_id(name, cluster_name)
      cluster = get_resource(service='clusters', query="name=#{cluster_name}")[0]
      cluster_networks = @connection.follow_link(cluster.networks)

      vnic_profiles = get_resource(service='vnic_profiles')
      vnic_profiles.each do |vnic_profile|
        if vnic_profile.name == name
          cluster_networks.each do |cluster_network|
            if vnic_profile.network.id == cluster_network.id
              return vnic_profile.id
            end
          end
        end
      end
    end

    def generate_ovirt_creds(ca_path)
      ovirt_creds = {}
      ovirt_creds["ovirt_url"] = @config[:api_url]
      ovirt_creds["ovirt_fqdn"] = @config[:api_url].gsub(/\/ovirt-engine\/api\/?$/,"")
      ovirt_creds["ovirt_pem_url"] = @pem_url
      ovirt_creds["ovirt_username"] = @config[:userdomain]
      ovirt_creds["ovirt_password"] = @config[:password]
      ovirt_creds["ovirt_cafile"] = "#{ca_path}"
      ovirt_creds["insecure"] = false

      return ovirt_creds
    end

    def trust_ovirt_certificate(ca_path=nil)
      if ca_path
        cmd = "cp #{ca_path} /tmp/ovirt.pem"
      else
        # ovirt credentials exposed here to get the ca, for testing only!
        cmd = "curl -k '#{@pem_url}' -o /tmp/ovirt.pem"
      end
      system("#{cmd}")

      anchors_dir = '/etc/pki/ca-trust/source/anchors'
      if Dir.exist?(anchors_dir)
        logger.info "Trusting ovirt certificate"
        cmd = "set -x; sudo chmod 0644 /tmp/ovirt.pem && \
               sudo cp /tmp/ovirt.pem #{anchors_dir} && \
               rm -rf /tmp/ovirt.pem && \
               update-ca-trust"
        system("#{cmd}")
        return File.join(anchors_dir, 'ovirt.pem')
      else
        logger.error "Failed to trust CA certificate, dir does not exist: #{anchors_dir}"
        exit 1
      end
    end

    def close_ovirt_connection()
      @connection.close
    end

  end
end
