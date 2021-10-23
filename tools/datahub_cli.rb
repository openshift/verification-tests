#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../tools")

"""
Helper utility to interact with AWS services on the command-line
"""

require 'commander'

require 'launchers/amz'
require 'text-table'

module BushSlicer
  class DataHubCLI
    include Commander::Methods
    include Common::Helper
    include Common::CloudHelper

    attr_accessor :dhub
    def initialize
      @dhub = BushSlicer::Amz_EC2.new(service_name: "DATA-HUB")
      always_trace!
    end

    def print_buckets(raw_data:, headers: ['name', 'date'])
      table = Text::Table.new
      table.head = headers
      raw_data.each do |bucket|
        row = [bucket.name, bucket.creation_date]
        table.rows << row
      end
      puts table
    end

    def print_bucket_object_details(raw_data:, headers: ['key', 'date', 'size'], opts:)
      table = Text::Table.new
      table.head = headers
      total_size = 0
      raw_data.each do |data|
        row = [data.key, data.last_modified, data.size]
        total_size += data.size
        table.rows << row
      end
      puts table
      print("Summary for #{opts.bucket}: #{raw_data.count} files, total size: #{total_size}\n")
    end

    def run
      program :name, 'DataHubCLI'
      program :version, '0.0.1'
      program :description, 'Helper utility to interface datahub s3 storage'

      #Commander::Runner.instance.default_command(:gui)
      default_command :help


      command :"show-buckets" do |c|
        c.syntax = "#{File.basename __FILE__} -b bucket_name"
        c.description = 'show all buckets in a space '
        c.action do |args, options|
          buckets = @dhub.s3_list_buckets
          print_buckets(raw_data: buckets)
        end
      end

      command :"list-bucket" do |c|
        c.syntax = "#{File.basename __FILE__} -b bucket_name"
        c.description = 'display objects in a bucket name'
        c.option("-b", "--bucket bucket", "this region only")
        c.option("-p", "--prefix prefix", "prefix of the objects to list")
        c.action do |args, options|
          options.default :prefix => '', :bucket => 'cucushift-html-logs'
          contents = @dhub.s3_list_bucket_contents(bucket: options.bucket, prefix: options.prefix)
          print("Found #{contents.count} objects\n")
        end
      end


      command :"delete-bucket" do |c|
        c.syntax = "#{File.basename __FILE__} -b bucket_name"
        c.description = 'display objects in a bucket name'
        c.option("-b", "--bucket bucket_name", "this region only")
        c.action do |args, options|
          raise "Missing option --bucket" unless options.bucket
          @dhub.s3_delete_bucket(bucket: options.bucket)
        end
      end

      command :"delete-bucket-objects" do |c|
        c.syntax = "#{File.basename __FILE__} -b bucket_name"
        c.description = 'delete object a given a bucket and its key'
        c.option("-b", "--bucket bucket_name", "query against this bucket")
        c.option("-p", "--prefix prefix", "filter on this prefix")

        c.action do |args, options|
          options.default :prefix => ''
          raise "Missing option --bucket" unless options.bucket
          @dhub.s3_batch_delete_from_bucket(bucket: options.bucket, prefix: options.prefix)
        end
      end

      run!
    end
  end
end

if __FILE__ == $0
  BushSlicer::DataHubCLI.new.run
end
