# for reference on how to use Metering please consult the following link
# https://github.com/operator-framework/operator-metering/blob/master/Documentation/using-metering.md

require 'openshift/flakes/condition'

module BushSlicer
  class Report < ProjectResource
    RESOURCE = "reports"

    # on occasions in which metering is just installed and we call to
    # generate report immediately, the raw_resource will return nil, in which case we just
    # return false
    def conditions(user: nil, cached: false, quiet: false)
      rr = raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'conditions')
      if rr.nil?
        return []
      else
        rr.map { |cond| Condition.new cond }
      end
    end

    def running?(user: nil, cached: false, quiet: false)
      # the reason 'Scheduled' is an initial state what we
      conditions.any? { |c| c.type == 'Running' and c.reason != 'Scheduled' }
    end

    # wait until the stauts of the Report becomes 'Finished'
    def wait_till_finished(user: nil, quiet: false)
      seconds = 60 # for PVs it can take longer than 30s
      success = wait_for(seconds) do
        finished?(user: user, quiet: quiet)
      end
      raise "Report '#{self.name}' didn't become :finished" unless success
      return success
    end

    # for scheduledreport or a report that has not reached the reportingEnd
    # time, we just need to check that the type is Running and
    def wait_till_running(user: nil, quiet: false)
      seconds = 60 # for PVs it can take longer than 30s
      success = wait_for(seconds) do
        running?(user: user, quiet: quiet)
      end
      raise "Report didn't become :running" unless success
      return success
    end

    def finished?(user: nil, quiet: false)
      ## TODO: make this backwardcompatible
      # phase(user:user, cached: cached, quiet: quiet) == :finished
      conditions.any? { |c| c.reason.end_with? 'Finished' }
    end

    def self.generate_yaml(**opts)
      schedule = opts[:schedule].nil? ? nil : YAML.load(opts[:schedule])
      report_hash = {
        "apiVersion" => "metering.openshift.io/v1alpha1",
        "kind" => 'Report',
        "metadata" => {
          "name" => opts[:metadata_name]
        },
        "spec" => {
          "reportingStart" => opts[:start_time],
          "reportingEnd" => opts[:end_time],
          "query" => opts[:query_type],
          "gracePeriod" => opts[:grace_period],
          "runImmediately" => opts[:run_immediately],
          "schedule" => schedule
        },
      }
      # delete the hash element if nil
      report_hash['spec'].compact!
      return report_hash.to_yaml
    end

    # Any existing report object matching will be deleted and re-created with the new paramter.
    # @require report_yaml
    def construct(user: nil, **opts)
      raise "Missing required parameter :report_yaml" unless opts.has_key? :report_yaml
      ## check reuse
      if opts[:use_existing_report]
        unless self.exists?
          # create if no report actually exsits
          @result = user.cli_exec(:create, f: "-", _stdin: opts[:report_yaml])
          raise "Failed to create report" unless @result[:success]
        end
      else
        self.ensure_deleted(user: user)
        @result = user.cli_exec(:create, f: "-", _stdin: opts[:report_yaml])
        raise "Failed to create report" unless @result[:success]
      end
    end
  end
end
