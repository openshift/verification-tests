#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../tools")

''"
Helper utility to interact with AWS services on the command-line
"''

require 'commander'

require 'launchers/amz'

require 'collections'
require 'common'
require 'cucuhttp'
require 'jenkins_api_client'
require 'text-table'
# GCE specific
require 'google/apis/compute_v1'
require 'googleauth'
require 'launchers/openstack'

# user libs
require 'resource_monitor'
require 'instance_auditor'


module BushSlicer
  class CloudWatch
    include Commander::Methods
    include Common::Helper
    include Common::CloudHelper
    attr_accessor :amz, :gce, :azure

    # TODO: perhaps we can cache the jenkins id mapping into a db instead to
    # to save time
    def initialize
      always_trace!
    end

    def run
      program :name, 'CloudWatch'
      program :version, '0.0.1'
      program :description, 'Helper utility to alert the team when'
      global_option('--no_slack') do |_f|
        no_slack = true
      end
      global_option('--skip_save') do |_f|
        skip_save = true
      end
      default_command :help

      command :aws do |c|
        c.syntax = "#{File.basename __FILE__} -r <aws_region_name> [--all]"
        c.description = 'display resource summary for AWS'
        c.action do |args, options|
          ps = AwsResources.new
          options.config = conf
          say 'Getting summary...'
          ps.summarize_resources
        end
      end

      command :aws_audit do |c|
        c.syntax = "#{File.basename __FILE__} -r <aws_region_name> [--all]"
        c.description = 'display instance summary for AWS at realtime'
        c.option("-r", "--region region_name", "report on this region only")
        c.option('--skip-save', "Skip saving data to DB when specified.")
        c.action do |args, options|
          ps = AwsAuditor.new(svc_name: :"AWS-CLOUD-USAGE")
          options.config = conf
          say 'Getting summary...'
          ps.get_summary(target_region: options.region, options: options)
          # China region use a separate cred, so need to call that specifically
          global_region = :"AWS-CI-CHINA"
          ps = AwsAuditor.new(svc_name: global_region)
          options.config = conf
          say 'Getting summary...'
          ps.get_summary(target_region: options.region, options: options,
            global_region: global_region
            )

        end
      end
      command :openstack do |c|
        c.syntax = "#{File.basename __FILE__}"
        c.description = 'display resource summary for Openstack'
        c.action do |args, options|
          ps = OpenstackResources.new
          options.config = conf
          say 'Getting summary...'
          ps.summarize_resources
        end
      end

      run!
    end
  end
end

BushSlicer::CloudWatch.new.run if __FILE__ == $0
