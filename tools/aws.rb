#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")

"""
Helper utility to interact with AWS services on the command-line
"""

require 'commander'

require 'launchers/amz'

require 'collections'
require 'common'
require 'cucuhttp'

module BushSlicer
  class AWSCli
    include Commander::Methods
    include Common::Helper
    include Common::CloudHelper

    def initialize
      always_trace!
    end

    def run
      program :name, 'AWS Helper'
      program :version, '0.0.1'
      program :description, 'Helper utility to interact with AWS services on the command-line'

      #Commander::Runner.instance.default_command(:gui)
      default_command :help

      global_option('-s', '--service SERVICE_NAME', 'AWS service name to lookup in config')

      command :template do |c|
        c.syntax = "#{File.basename __FILE__} template -l <instance name>"
        c.description = 'launch instances according to template'
        c.action do |args, options|
          say 'launching..'
          launch_template(**options.default)
        end
      end

      command :"s3-upload" do |c|
        c.syntax = "#{File.basename __FILE__} s3-upload -f <file> -b <bucket> [-t <target key>]"
        c.description = 'upload file to S3'
        c.option("-b", "--bucket BUCKET", "upload to this bucket")
        c.option("-f", "--file FILE", "file to upload")
        c.option("-t", "--target TARGET", "key for file in the bucket (defaults to file name}")
        c.action do |args, options|
          say 'Uploading..'
          options.service_name ||= :AWS
          options.service_name = options.service_name.to_sym

          s3_upload_file(options)
        end
      end

      command :fiddle do |c|
        c.syntax = "#{__FILE__} fiddle"
        c.description = 'enter a pry shell to play with API'
        c.action do |args, options|
          require 'pry'
          binding.pry
        end
      end

      run!
    end

    def s3_upload_file(options)
      amz = Amz_EC2.new(service_name: options.service_name)
      amz.s3_upload_file(bucket: options.bucket, file: options.file, target: options.target)
    end

  end
end

if __FILE__ == $0
  BushSlicer::AWSCli.new.run
end
