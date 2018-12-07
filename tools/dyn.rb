#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")

"""
Utility to manage Dynect DNS entries
"""

require 'commander'

require 'common'
require 'launchers/dyn/dynect'

module VerificationTests
  class DynManager
    include Commander::Methods
    include Common::Helper

    def initialize
      always_trace!
    end

    def run
      program :name, 'Dyn Manager'
      program :version, '0.0.1'
      program :description, 'Tool to manage Dynect DNS'

      #Commander::Runner.instance.default_command(:gui)
      default_command :help

      #global_option('-s', '--service KEY', 'service name to look for in configuration')

      command :fiddle do |c|
        c.syntax = "#{__FILE__} fiddle"
        c.description = 'enter a pry shell to play with API'
        c.action do |args, options|
          require 'pry'
          binding.pry
        end
      end

      command :list do |c|
        c.syntax = 'dyn.rb list'
        c.description = 'list zone records'
        c.action do |args, options|
          puts *dyn.dyn_get_all_zone_records
        end
      end

      command :create_a do |c|
        c.syntax = 'dyn.rb create_a [options]'
        c.description = 'create A record depending on opts'
        c.option('--ips LIST', "comma separated target IPs")
        # c.option('--domain', "the target domain if random not appropriate")
        c.action do |args, options|
          ips = options.ips.split(",")
          say dyn.dyn_create_random_a_wildcard_records(ips)
          dyn.publish
        end
      end

      command :delete_older_records do |c|
        c.syntax = 'dyn.rb delete_older_records [options]'
        c.description = 'delete records older than some time'
        c.option('-w', '--weeks NUM', "number of weeks older records to delete")
        c.option('--doit', 'actually perform the operation; dry run otherwise')

        c.action do |args, options|
          weeks = Integer(options.weeks)
          raise "please specify time to remove older records" unless weeks

          # weeks + 1 day (avoid rounding errors)
          time = Time.now - (weeks * 7 + 1) * 24 * 3600
          puts *dyn.delete_older_timed_records(time)
          if options.doit
            dyn.publish
          else
            puts "Dry run, no changes done"
          end
        end
      end

      run!
    end

    def dyn
      unless @dyn
        @dyn = Dynect.new
        at_exit do
          @dyn.close
        end
      end
      return @dyn
    end
  end
end

if __FILE__ == $0
  VerificationTests::DynManager.new.run
end
