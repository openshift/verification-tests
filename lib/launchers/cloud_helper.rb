# should not require 'common'
# should only include helpers that do NOT load any other BushSlicer classes

module BushSlicer
  module Common
    module CloudHelper
      # based on information in https://github.com/openshift/vagrant-openshift/blob/master/lib/vagrant-openshift/templates/command/init-openshift/box_info.yaml
      # returns the proper username given the type of base image specified
      def get_username(image='rhel7')
        username = nil
        case image
        when 'rhel7', 'rhel7next'
          username = 'ec2-user'
        when 'centos7'
          username = 'centos'
        when 'fedora'
          username = 'fedora'
        when 'rhelatomic7'
          username = 'cloud-user'
        else
          raise "Unsupported image type #{image}"
        end
        return username
      end

      def iaas_by_service(service_name)
        case conf[:services, service_name, :cloud_type]
        when "aws"
          Amz_EC2.new(service_name: service_name)
        when "azure"
          BushSlicer::Azure.new(service_name: service_name)
        when "openstack"
          BushSlicer::OpenStack.new(service_name: service_name)
        when "gce"
          BushSlicer::GCE.new(service_name: service_name)
        when "vsphere"
          BushSlicer::VSphere.new(service_name: service_name)
        when "alibaba"
          BushSlicer::Alicloud.new(service_name: service_name)
        when "packet"
          BushSlicer::Packet.new(service_name: service_name)
        when "ibmcloud"
          BushSlicer::IBMCloud.new(service_name: service_name)
        when "arm_bm"
          BushSlicer::ARMRdu2.new(service_name: service_name)
        when "rdu_ipi_bm"
          BushSlicer::Rdu_IPI_BM.new(service_name: service_name)
        when "nutanix"
          BushSlicer::Nutanix.new(service_name: service_name)
        else
          raise "unknown service type " \
            "#{conf[:services, service_name, :cloud_type]} for cloud " \
            "#{service_name}"
        end
      end
    end
  end
end

