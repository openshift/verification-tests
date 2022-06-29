require 'open3'

require 'bushslicer'
require 'manager'
require 'base_helper'

module BushSlicer
  module Common
    module Helper
      include BaseHelper

      def manager
        BushSlicer::Manager.instance
      end

      def conf
        manager.conf
      end

      def logger
        manager.logger
      end

      def localhost
        Host.localhost
      end

      # find an absolute file, relative to private, home or workdir;
      #   relative to main repo it is not allowed to avoid leaks if possible
      def expand_private_path(path, public_safe: false)
        if Host.localhost.file_exist?(path)
          # absolute path or relative to workdir
          return Host.localhost.absolute_path(path)
        elsif File.exist?(PRIVATE_DIR + "/" + path)
          return PRIVATE_DIR + "/" + path
        elsif public_safe && File.exist?(BushSlicer::HOME + "/" + path)
          return BushSlicer::HOME + "/" + path
        elsif File.exist?(File.expand_path("~/#{path}"))
          return File.expand_path("~/#{path}")
        else
          raise "cannot lookup private path: #{path}"
        end
      end

      def expand_path(path, public_safe: true)
        expand_private_path(path, public_safe: public_safe)
      end

      # the 'oc describe xxx' output is key-value formatted with ':' as the
      #  separator.
      def parse_oc_describe(oc_output)
        result = {}
        ### the following has become un-reliable per bugs https://bugzilla.redhat.com/show_bug.cgi?id=1268954 & https://bugzilla.redhat.com/show_bug.cgi?id=1268933
        ## for now, we disable the parsing part and just use regexp to capture properties that is of interest
        # multi_line_key = nil
        # multi_line = false
        # oc_output.each_line do |line|
        #   if multi_line
        #     if line.size == 0
        #       # multline value ended reset it for the next prop
        #       multi_line = false
        #       multi_line_key = nil
        #     else
        #       result[multi_line_key] += line + "\n"
        #     end
        #   else
        #     name, sep, val = line.partition(':')
        #     if val == "\n"
        #       # multiline output
        #       multi_line_key = name
        #       result[name] = ""
        #       multi_line = true
        #     else
        #       result[name] = val.strip()
        #     end
        #   end
        # end
        # more parsing for commonly used properties
        pods_regexp = /Pods Status:\s+(\d+)\s+Running\s+\/\s+(\d+)\s+Waiting\s+\/\s+(\d+)\s+Succeeded\s+\/\s+(\d+)\s+Failed/
        replicas_regexp = /Replicas:\s+(\d+)\s+current\s+\/\s+(\d+)\s+desired/
        labels_regexp = /Labels:\s+(.+)/
        selectors_regexp = /Selector:\s+(.+)/
        images_regexp = /Images(s):\s+(.+)/
        status_regexp = /\s+Status:\s+(.+)/


        pods_status = pods_regexp.match(oc_output)
        replicas_status = replicas_regexp.match(oc_output)
        overall_status = status_regexp.match(oc_output)
        selectors_status = selectors_regexp.match(oc_output)
        images_status = images_regexp.match(oc_output)

        if pods_status
          result[:pods_status] = {:running => pods_status[1], :waiting => pods_status[2],
            :succeeded=>pods_status[3], :failed => pods_status[4]}
        end
        if replicas_status
          result[:replicas_status] = {:current => replicas_status[1], :desired => replicas_status[2]}
        end
        result[:images] = images_status[1] if images_status
        result[:overall_status] = overall_status[1] if overall_status
        result[:selectors] = selectors_status[1] if selectors_status

        return result
      end

      # @param [Environment] env to read proxy from
      # @param [Hash, Array] opts to put `_env` option to if it is not there already
      def add_proxy_env_opt(env, opts)
        if env.client_proxy
          opts_env_pair = opts.find{ |k,v| k == :_env }
          opts_env = Collections.to_env_hash( opts_env_pair&.last || {} )
          unless opts_env[:http_proxy] || opts_env["http_proxy"] ||
              opts_env[:https_proxy] || opts_env["https_proxy"]

            opts_env = opts_env.merge({
              "http_proxy" => env.client_proxy,
              "https_proxy" => env.client_proxy,
            })

            case opts
            when Hash
              opts[:_env] = opts_env
            when Array
              if opts_env_pair
                opts_env_pair[1] = opts_env
              else
                opts << [:_env, opts_env]
              end
            end
          end
        end
      end

      # hack to have host.rb autoloaded when it is used through Helper outside
      # Cucumber (at the same time avoiding circular dependencies). That avoids
      # need for the external script to know that host.rb is required.
      BushSlicer.autoload :Host, "host"
    end # module Helper

    # some ugly hack that we need to be more reliable
    module Hacks
      # we'll try calling this one after common pry calls as well by affected
      #   thread users (to make sure we didn't miss some pry call)
      def fix_require_lock
        if defined?(Pry) &&
           Kernel::RUBYGEMS_ACTIVATION_MONITOR.instance_variable_get(:@mon_owner) == Thread.current
          Kernel.puts("ERROR: Detected stale RUBYGEMS_ACTIVATION_MONITOR lock, see: https://bugzilla.redhat.com/show_bug.cgi?id=1257578")
          Kernel::RUBYGEMS_ACTIVATION_MONITOR.mon_exit
        end
      rescue => e
        Kernel.puts("ERROR: Ruby private API changed? cannot execute fix_require_lock: #{e.inspect}")
      end

      # emulate the #dig method of ruby 2.3 into Hash
      if !::Hash.instance_methods.include?(:dig)
        class ::Hash
          def dig(*keys)
            if keys.empty?
              raise ArgumentError,
                "wrong number of arguments (given 0, expected 1+)"
            end
            val = self
            keys.all? {|key| val = val[key]}
            return val
          end
        end
      end

      # ensure Hash#transform_values method exists
      if !::Hash.instance_methods.include?(:transform_values)
        require 'active_support/core_ext/hash/transform_values.rb'
      end
    end

    module Setup
      def self.handle_signals
        # Cucumber traps SIGINT and SIGTERM to allow graceful shutdown
        # see https://github.com/cucumber/cucumber/issues/27
        Signal.trap('SIGINT') { exit(false) }
        #Signal.trap('SIGTERM') { exit(false) } # it works like that already
      end

      def self.set_bushslicer_home
        # BushSlicer.const_set(:HOME, File.expand_path(__FILE__ + "../../.."))
        BushSlicer::HOME.freeze
        ENV["BUSHSLICER_HOME"] = BushSlicer::HOME
      end
    end
  end
end
