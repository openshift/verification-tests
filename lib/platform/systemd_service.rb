module BushSlicer
  module Platform
    # Class which represents a generic openshift service running on a host
    class SystemdService
      include Common::BaseHelper

      attr_reader :host, :services, :expected_load_time, :name

      # @param name [Sting] name of systemd service
      def initialize(service_name, host, **opts)
        @name = service_name
        @host = host
        @expected_load_time = opts[:expected_load_time] || 20

        unless String === service_name && !service_name.empty?
          raise "No service name provided!"
        end
      end

      def self.configured?(service_name, host)
        host.exec_admin("systemctl is-active '#{service_name}'")[:success]
      end

      def self.enabled?(service_name, host)
        result = host.exec_admin("systemctl is-enabled '#{service_name}'")
        result[:success] && (result[:stdout].to_s.include? "enabled")
      end

      def status(quiet: false)
        statuses = {
          active: "active",
          activating: "activating",
          deactivating: "deactivating",
          inactive: "inactive",
          failed: "failed"
        }

        # interesting whether `systemctl is-active svc` is better
        result = host.exec_admin("systemctl --lines=0 status #{name}", quiet: quiet)
        if result[:response].include? "Active:"
          result[:success] = true
        else
          raise "could not execute systemctl:\n#{result[:response]}"
        end

        statuses.keys.each do |key|
          if result[:response] =~ /Active:\s+#{statuses[key]}/
            result[:status] = key
            return result
          end
        end
        result[:status] = :unknown
        return result
      end

      def logger
        host.logger
      end

      # Will stop the provided service.
      # @param opts [Hash] see supported options below
      #   :raise [Boolean] raise if stop fails
      def stop(**opts)
        results = []
        current_status = status(quiet: true)

        case current_status[:status]
        when :inactive, :failed
          logger.warn "Stop is requested for service #{name} on " \
            "#{host.hostname} but it is already #{current_status[:status]}."
          return current_status
        else
          logger.info "before stop, status of service #{name} on " \
            "#{host.hostname} is: #{current_status[:status]}"
          results.push(current_status)
        end

        result = host.exec_admin("systemctl stop #{name}")
        results.push(result)
        unless result[:success]
          if opts[:raise]
            raise "could not stop service #{name} on #{host.hostname}"
          end
          return BushSlicer::ResultHash.aggregate_results(results)
        end

        sleep 5 # lets guess some hardcoded sleep after stop for the time being

        result = status
        results.push(result)

        # some pre-3.9 versions of OpenShift reported failed status on stop
        # https://bugzilla.redhat.com/show_bug.cgi?id=1557851
        unless [:inactive, :failed].include?(result[:status])
          result[:success] = false
          err_msg = "service #{name} on #{host.hostname} still " \
            "#{result[:status]} 5 seconds after stop command"
          if opts[:raise]
            raise err_msg
          else
            logger.warn err_msg
          end
        end

        return BushSlicer::ResultHash.aggregate_results(results)
      end

      # Will restart the service.
      # @param opts [Hash] see supported options below
      #   :raise [Boolean] raise if restart fails
      def restart(**opts)
        results = []
        logger.info "before restart status of service #{name} on " \
          "#{host.hostname} is: #{status(quiet: true)[:status]}"

        result = host.exec_admin("systemctl restart #{name}")
        results.push(result)
        unless result[:success]
          # we should always check status if restart fails
          host.exec_admin("systemctl status -l #{name}", quiet: false)
          if opts[:raise]
            raise "could not restart service #{name} on #{host.hostname}"
          end
          return BushSlicer::ResultHash.aggregate_results(results)
        end

        ## this below seems to not make much sense
        #terminal_statuses = [:active, :inactive]
        #stable_status = wait_for(120) {
        #  result = status(service, quiet: true)
        #  terminal_statuses.include? result[:status]
        #}
        #results.push(result)
        #
        #unless stable_status
        #  # the `:raise` option is not respected here because unless service
        #  #   reach some stable status, we can't say for sure whether
        #  #   restart failed or not (it could be just too slow)
        #  raise BushSlicer::TimeoutError,
        #    "service #{service} on #{host.hostname} never reached " \
        #    "a stable status:\n#{result[:response]}"
        #end
        #
        #if result[:status] == :active
          sleep expected_load_time
          result = status
          results.push(result)
          unless result[:status] == :active
            result[:success] = false
            err_msg = "service #{name} on #{host.hostname} died after " \
              "#{expected_load_time} seconds"
            if opts[:raise]
              raise err_msg
            else
              logger.warn err_msg
            end
          end
        #else
        #  result[:success] = false
        #  err_msg = "service #{service} on #{host.hostname} could not be" \
        #    "activated:\n#{result[:response]}"
        #  if opts[:raise]
        #    raise BushSlicer::TimeoutError, err_msg
        #  else
        #    logger.warn err_msg
        #  end
        #end

        return BushSlicer::ResultHash.aggregate_results(results)
      end

      # Will restart the service.
      # @param opts [Hash] see supported options below
      #   :raise [Boolean] raise if restart fails
      def start(**opts)
        results = []
        current_status = status(quiet: true)

        case current_status[:status]
        when :activating, :active
          logger.warn "Start is requested for service #{name} on " \
            "#{host.hostname} but it is already #{current_status[:status]}."
          return current_status
        else
          logger.info "before start, status of service #{name} on " \
            "#{host.hostname} is: #{current_status[:status]}"
          results.push(current_status)
        end

        result = host.exec_admin("systemctl start #{name}")
        results.push(result)
        unless result[:success]
          if opts[:raise]
            raise "could not start service #{name} on #{host.hostname}"
          end
          return BushSlicer::ResultHash.aggregate_results(results)
        end

        sleep expected_load_time
        result = status
        results.push(result)
        unless result[:status] == :active
          result[:success] = false
          err_msg = "service #{name} on #{host.hostname} died after " \
            "#{expected_load_time} seconds"
          if opts[:raise]
            raise err_msg
          else
            logger.warn err_msg
          end
        end

        return BushSlicer::ResultHash.aggregate_results(results)
      end
    end
  end
end
