# for reference on how to use Metering please consult the following link
# https://github.com/operator-framework/operator-metering/blob/master/Documentation/using-metering.md
module BushSlicer
  class Report < ProjectResource
    RESOURCE = "reports"

    def finished?(user: nil, cached: false, quiet: false)
      phase(user:user, cached: cached, quiet: quiet) == :finished
    end

    # wait until the stauts of the Report becomes 'Finished'
    def wait_till_finished(user: nil, quiet: false)
      seconds = 30
      success = wait_for(seconds) do
        finished?(user:user, cached: false, quiet: quiet)
      end
      raise "Report didn't become :finished" unless success
      return success
    end

    # need 4 inputs
    # a. ReportGenerationQuery
    # b. reportingStart
    # c. reportingEnd
    # d. runImmediately
    def self.generate_yaml(query_type: self.name, start_time: nil, end_time: nil, run_now: "true")
      # span the whole year if user didn't give a range
      start_time ||= "#{Time.now.year}" + "-01-01T00:00:00Z"
      end_time ||= "#{Time.now.year}" + "-12-30T23:59:59Z"
      run_immediately ||= "true"

      report = <<BASE_TEMPLATE
        apiVersion: metering.openshift.io/v1alpha1
        kind: Report
        metadata:
          name: #{query_type}
        spec:
          reportingStart: #{start_time}
          reportingEnd: #{end_time}
          generationQuery: #{query_type}
          runImmediately: #{run_immediately}
BASE_TEMPLATE
      return report
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
