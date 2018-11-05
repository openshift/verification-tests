module BushSlicer
  module Platform
    # service controlled by custom scripting
    class ScriptService
      include Common::BaseHelper

      attr_reader :host, :os_user, :start_script, :stop_script, :restart_script, :name
      private :host, :os_user, :start_script, :stop_script, :restart_script

      # @param name [String] symbolic name of the service
      # @param start [String, Array<String>] script to start service
      # @param stop [String, Array<String>] script to stop service
      # @param os_user [String, :admin] optional operating system user to execure scripts as
      # @param host [Host] the host where service is running
      def initialize(start:, stop:, restart: nil, host:, os_user: :admin, name:)
        @host = host
        @os_user = os_user
        @start_script = start
        @stop_script = stop
        @restart_script = restart
        @name = name
      end

      # execute script on host
      # @param op [String] symolic name of script used for reporting
      # @param script [String, Array<String>] script to execute
      # @param opts [Hash] see supported options below
      #   :raise [Boolean] raise if stop fails
      private def exec_script(op, script, **opts)
        result = host.exec_as(os_user, script)
        if !result[:success] && opts[:raise]
          raise "init script #{op} failed for service #{self.name} on #{host.hostname}"
        else
          return result
        end
      end

      # Start the service.
      # see #exec_script
      def start(**opts)
        exec_script(:start, start_script, **opts)
      end


      # Stop the service.
      # see #exec_script
      def stop(**opts)
        exec_script(:stop, stop_script, **opts)
      end

      # Restart the service.
      # see #exec_script
      def restart(**opts)
        if restart_script
          exec_script(:restart, restart_script, **opts)
        else
          BushSlicer::ResultHash.aggregate_results [
            stop(**opts),
            start(**opts)
          ]
        end
      end
    end
  end
end
