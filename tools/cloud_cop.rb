#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")

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

# user libs
require 'instance_summary'
require 'jenkins'

module BushSlicer
  class CloudCop
    include Commander::Methods
    include Common::Helper
    include Common::CloudHelper
    attr_accessor :jenkins, :jenkins_build_map, :summary, :amz, :gce, :azure
    def initialize
      @jenkins = Jenkins.new
      @jenkins.construct_jenkins_build_map
      always_trace!
    end

    def run
      program :name, 'CloudCop'
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
          say 'WIP, please check back later'
        end
      end

      run!
    end
  end
end

if __FILE__ == $0
  BushSlicer::CloudCop.new.run
end
