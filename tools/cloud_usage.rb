#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../tools")

"""
Helper utility to interact with AWS services on the command-line
"""

require 'commander'

require 'launchers/amz'

require 'collections'
require 'common'
require 'http'
require 'thread'
require 'jenkins_api_client'
require 'text-table'
# GCE specific
require 'google/apis/compute_v1'
require 'googleauth'
require 'launchers/openstack'
# user libs
require 'instance_summary'
require 'jenkins'

module BushSlicer
  class CloudUsage
    include Commander::Methods
    include Common::Helper
    include Common::CloudHelper
    attr_accessor :jenkins, :jenkins_build_map, :amz, :gce, :azure
    # TODO: perhaps we can cache the jenkins id mapping into a db instead to
    # to save time
    def initialize
      @jenkins = Jenkins.new
      @jenkins.construct_jenkins_build_map unless @jenkins.build_map
      always_trace!
    end

    def run
      program :name, 'CloudUsage'
      program :version, '0.0.1'
      program :description, 'Helper utility to display summary of running instances in supported cloud platforms'

      #Commander::Runner.instance.default_command(:gui)
      default_command :help


      command :"aws" do |c|
        c.syntax = "#{File.basename __FILE__} -r <aws_region_name> [--all]"
        c.description = 'display summary of running instances'
        c.option("-r", "--region region_name", "report on this region only")
        c.action do |args, options|
          ps = AwsSummary.new(jenkins: @jenkins)
          say 'Getting summary...'
          ps.get_summary(target_region: options.region)

        end
      end

      command :"gce" do |c|
        c.syntax = "#{File.basename __FILE__} -r <gce_region_name> [--all]"
        c.description = 'display summary of running instances'
        c.option("-r", "--region region_name", "report on this region only")
        c.action do |args, options|
          ps = GceSummary.new(jenkins: @jenkins)
          ps.get_summary(target_region: options.region)
        end
      end
      command :"azure" do |c|
        c.syntax = "#{File.basename __FILE__}"
        c.description = 'display summary of running instances'
        c.action do |args, options|
          ps = AzureSummary.new(jenkins: @jenkins)
          ps.get_summary
        end
      end
      # internal openstack
      command :"upshift" do |c|
        c.syntax = "#{File.basename __FILE__}"
        c.description = 'display summary of running instances'
        c.action do |args, options|
          ps = OpenstackSummary.new(jenkins: @jenkins)
          ps.get_summary
        end
      end
      # packet
      command :"packet" do |c|
        c.syntax = "#{File.basename __FILE__}"
        c.description = 'display summary of running instances'
        c.action do |args, options|
          ps = PacketSummary.new(jenkins: @jenkins)
          ps.get_summary
        end
      end
      # VSphere
      command :"vms" do |c|
        c.syntax = "#{File.basename __FILE__}"
        c.description = 'display summary of running instances'
        c.action do |args, options|
          vms = VSphereSummary.new(jenkins: @jenkins)
          vms.get_summary
        end
      end
      run!
    end
  end
end

if __FILE__ == $0
  BushSlicer::CloudUsage.new.run
end
