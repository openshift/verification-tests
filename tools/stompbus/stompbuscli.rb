#!/usr/bin/env ruby
# frozen_string_literal: true

"""
Utility to enable some PolarShift operations via CLI
"""

require 'commander'

require_relative '../common/load_path'
require_relative "stompbus"
# require 'common'


module BushSlicer
  class STOMPBusCli
    include Commander::Methods
    # include Common::Helper

    def initialize
      always_trace!
    end

    def run
      program :name, 'STOMP Bus CLI'
      program :version, '0.0.1'
      program :description, 'Tool to interact with STOMP Bus via CLI'

      #Commander::Runner.instance.default_command(:gui)
      default_command :help

      global_option('-h', '--hosts HOST', 'comman separated bus listen hosts')
      global_option('-p', '--port PORT', 'bus listen port')
      global_option('--service_name SERVICE', 'service name for bus in config')
      global_option('--ssl SSL', 'whether the bus uses SSL')

      command :fiddle do |c|
        c.syntax = "#{__FILE__} fiddle"
        c.description = 'enter a pry shell to play with API'
        c.action do |args, options|
          require 'pry'
          binding.pry
        end
      end

      command :publish do |c|
        c.syntax = "#{$0} publish [options]"
        c.description = 'publish a message to the message bus'
        c.option('-d', '--destination DESTINATION',
                                     "destination to send message to")
        c.option('-m', '--message MESSAGE', "message body to be sent")
        c.option('-o', '--header HEADER', "message header (as valid YAML)")
        c.option('-f', '--file FILE', "read message from a file")
        c.action do |args, options|
          setup_global_opts(options)

          if options.file
            msg = YAML.safe_load_file options.file, aliases: true, permitted_classes: [Symbol, Regexp]
            msg[:body] = msg[:body].to_json unless String === msg[:body]
          elsif options.message
            msg = { body: options.message }
          elsif ENV["STOMP_MESSAGE"] && !ENV["STOMP_MESSAGE"].strip.empty?
            msg = { body: ENV["STOMP_MESSAGE"] }
          else
            raise "you must specify message to be sent"
          end

          if options.header
            msg[:header] = YAML.safe_load options.header, aliases: true, permitted_classes: [Symbol, Regexp]
          elsif ENV["STOMP_HEADER"] && !ENV["STOMP_HEADER"].strip.empty?
            msg[:header] = YAML.safe_load ENV["STOMP_HEADER"], aliases: true, permitted_classes: [Symbol, Regexp]
          else
            msg[:header] = {}
          end

          destination = options.destination || msgbus.default_queue
          raise "no destination specified" unless destination

          client = msgbus.new_client
          client.publish(destination, msg[:body], msg[:header])
          client.close
        end
      end

      command :subscribe do |c|
        c.syntax = "#{$0} subscribe [options]"
        c.description = 'listen for messages on the message bus'
        c.option('-c', '--count COUNT', "listen for up to count messages")
        c.option('-q', '--queue QUEUE', "queue to listen to")
        c.option('-f', '--filter FILTER', "message filter (SQL)")
        c.action do |args, options|
          setup_global_opts(options)

          headers = {}
          headers[:selector] = options.filter if options.filter
          queue = options.queue || msgbus.default_queue
          raise "no queue specified" unless queue

          client = msgbus.new_client
          count = Integer(options.count) if options.count
          puts "Press ctrl + c to exit...\n\n"
          client.subscribe(queue, headers) do |msg|
            puts STOMPBus.msg_to_str(msg)
            if count
              count = count - 1
              client.close if count <= 0
            end
          end

          begin
            client.join
          rescue Interrupt
          ensure
            unless client.closed?
              # client.unsubscribe(queue, headers)
              client.close
            end
          end
        end
      end

      run!
    end

    private def msgbus
      @msgbus ||= STOMPBus.new(opts)
    end

    # bus connection options
    def opts
      @opts || raise('please first call `setup_global_opts(options)`')
    end

    # @param options [Ostruct] options as processed by Commander
    def setup_global_opts(options)
      allowed = [:hosts, :port, :ssl, :service_name]
      opts = {}
      options.default.each { |key, value|
        opts[key] = value if allowed.include? key
      }
      @opts = opts
    end
  end
end

if __FILE__ == $0
  BushSlicer::STOMPBusCli.new.run
end
