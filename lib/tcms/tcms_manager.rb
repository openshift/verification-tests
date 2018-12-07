require 'thread' # for the uploader thread
require 'tmpdir'
require 'fileutils'
require 'find'
require 'ostruct' # for TCMSTestCase
require 'json'

require 'common'
require_relative 'tcms'

module VerificationTests
  # this is our TCMS test case manager
  # tried to make it quick and dirty but it became only dirty
  class TCMSManager
    include Common::Helper
    include Common::Hacks

    attr_accessor :current_test_case, :opts
    # attr_reader :attach_queue

    def initialize(**opts)
      @opts = opts

      # will contain [caserun_id, directory] pairs to upload;
      #   when thread sees a `false` value, it will quit
      @attach_queue = Queue.new
      @attacher = Thread.new do
        while workitem = @attach_queue.pop # yes, assignment
          handle_attach(workitem)
        end
      end
    end

    ############ test case manager interface methods ############

    # act according to signal from VerificationTests
    #   job == TCMS test case == some set of Cucumber scenarios/test cases
    #   test case == Cucumber scenario
    # @note see [TCMSTestCaseRun#overall_status=] for how status works
    def signal(signal, *args)
      fix_require_lock # see method in Common::Hacks

      case signal
      when :end_of_cases
      when :start_case
        ## mark specified scenario from current job as executing
        test_case = args[0]
        job = current_job(test_case)
        job.executing!(test_case)
      when :end_case
        ## mark the specified scenario from current job as completed
        test_case = args[0]
        job = current_job(test_case)
        ## generate/upload logs and other artifacts to TCMS
        handle_formatter_artifacts(job, test_case)
        job.completed!(test_case)
        @before_failed = false
        @after_failed = false
        ## set TCMS test case final status in TCMS
        if job.completed?
          tcms_final_status(job)
          finished_jobs << ready_jobs.delete(job)
        end
      when :finish_before_hook
        test_case = args[0]
        err = args[1]
        job = current_job(test_case)
        if err
          job.overall_status = "ERROR"
          @before_failed = true
        else
          job.overall_status = test_case.passed? ? "PASSED" : "FAILED"
        end
      when :finish_after_hook
        test_case = args[0]
        err = args[1]
        job = current_job(test_case)
        if err
          job.overall_status = "ERROR"
          @after_failed = true
        else
          job.overall_status = test_case.passed? ? "PASSED" : "FAILED"
        end
      when :at_exit
        if @incomplete_jobs
          finished_jobs.each do |job|
            Kernel.puts("case #{job.case_id} executed")
          end
          locked_jobs.each do |job|
            Kernel.puts("case #{job.case_id} was not IDLE")
          end
          ready_jobs.each do |job|
            Kernel.puts("case #{job.case_id} not executed (completely)")
          end
          non_runnable_jobs.each do |job|
            Kernel.puts("case #{job.case_id} not runnable")
          end
          incomplete_jobs.each do |job|
            Kernel.puts("case #{job.case_id} could not find all scenarios")
          end
        end

        ## let attacher know we finish and wait for queue drain
        @attach_queue << false
        wait_for_attacher
        @artifacts_filer.clean_up if @artifacts_filer
        # TODO: check `zlib(finalizer): the stream was freed prematurely.`
      end
    end

    def after_failed?
      @after_failed
    end

    def before_failed?
      @before_failed
    end

    # @param test_case [Cucumber::Core::Test::Case]
    def push(test_case)
      job = incomplete_jobs.find { |job| job.matches?(test_case) }
      if job && job.ready? # job may still require more scenarios
        ready_jobs << incomplete_jobs.delete(job)
      #elsif job.nil?
      #  Kernel.puts("skipping #{test_case.location.to_s} for no cases match it")
      end
    end

    # return next cucumber test_case to be executed and sets status to RUNNING
    def next
      # try to set next job to running (already running is ok)
      until ready_jobs.empty? || ready_jobs.first.running?
        unless set_to_running(ready_jobs.first)
          locked_jobs << ready_jobs.shift # some other executor running this
        end
      end
      if ready_jobs.empty?
        return nil
      else
        return ready_jobs.first.next_cucumber_test_case
      end
    end

    ############ test case manager interface methods end ############

    private

    # let some time attacher perform its duties
    def wait_for_attacher
      # wait for artifacts upload/attach
      # FYI if we join without timeout, it sometimes can raise error:
      #   No live threads left. Deadlock?
      # That's because thread is in sleep while waiting for queue item and
      #   without timeout, there is no guarantee it will ever return.
      # See also locking issue with pry vs yard-cucumber
      #   https://bugzilla.redhat.com/show_bug.cgi?id=1257578
      #   https://github.com/pry/pry/issues/1465
      # We try to warn an fix the above with call to #fix_require_lock
      if !@attacher.join(120)
        if conf[:debug_attacher_timeout]
          require 'pry'
          binding.pry
        end
        logger.error("Attacher thread join timeout, state: #{@attacher.status}")
        logger.error(@attacher.backtrace.join("\n"))
      end
    end

    # executed from within the attacher thread to actually upload/attach log;
    #   for workitem format, see [#handle_formatter_artifacts]
    def handle_attach(workitem)
      job, dir = workitem
      relative_path = File.join(*TIME_SUFFIX)
      remote_path = File.join(
        conf[:services, :artifacts_file_server, :upload_path],
        relative_path
      )
      base_url = File.join(
        conf[:services, :artifacts_file_server, :url],
        relative_path,
        File.basename(dir)
      )
      ## upload files
      artifacts_filer.copy_to(dir, remote_path, raw: true)

      ## link uploaded files in TCMS
      specs = []
      dirchars = dir.length + ( dir.end_with?("/","\\") ? 0 : 1 )
      Find.find(dir) do |file|
        if File.file? file
          specs << [
            File.basename(file),
            File.join(base_url, file[dirchars..-1])
          ]
        end
      end
      link_logs_to_tcms_async(job.case_run_id, specs)
    rescue => e
      Kernel.puts exception_to_string(e)
    ensure
      FileUtils.remove_entry dir
    end

    # @param specs [Array<Array>] list [name, URL] pairs
    # @param caserun_id [Numeric]
    # @note run by attacher thread; ignore errors, TCMS should log them anyway
    def link_logs_to_tcms_async(caserun_id, specs)
      op = 'TestCaseRun.attach_log'
      commands = specs.map { |name, url| [op, caserun_id, name, url] }
      if commands.size == 1
        not_err, res = tcms.call2_async(*commands[0])
      else
        not_err, res = tcms.multicall2_async(*commands)
      end
    end

    # @param job [TCMSTestCase]
    # @param test_case [Cucumber::Core::Test::Case]
    # @note to avoid upload/attaching delay, perform rsync and attach within
    #   a thread
    def handle_formatter_artifacts(job, test_case)
      return unless job.caserun?

      manager.custom_formatters.each do |formatter|
        ## move artifacts to a separate dir
        dir = formatter.process_scenario_log(after_failed: after_failed?,
                                             before_failed: before_failed?)
        #target_dir = Dir.mktmpdir("verification-tests_artifacts_")
        #FileUtils.mv dir, target_dir

        ## add attach_queue workitem
        @attach_queue << [job, dir]
        # to use main thread for debugging use following line instead:
        # handle_attach([job, dir])
      end
    end

    # @return [VerificationTests::Host] of the server storing logs and artifacts
    def artifacts_filer
      @artifacts_filer if @artifacts_filer

      @artifacts_filer = VerificationTests.
        const_get(conf[:services, :artifacts_file_server, :host_type]).
        new(
          conf[:services, :artifacts_file_server, :hostname],
          **conf[:services, :artifacts_file_server]
        )
      return @artifacts_filer
    end

    def tcms
      return @tcms ||= TCMS.new(opts[:tcms_opts] || {})
    end

    # @param job [TCMSTestCase]
    def tcms_final_status(job)
      return unless job.caserun?

      tcms.update_caserun_status(job.case_run_id , job.overall_status)
    end

    # reserve a test case run or return false
    # @return false when could not lock case
    def set_to_running(job)
      if !job.caserun?
        job.running!
        return true
      end

      # sometimes one of the properties might be missing
      if job.case_run_status_id != 1 && job.case_run_status != 'IDLE'
        return false
      end
      cur_status = tcms.get_caserun_status(job.case_run_id)
      return false if cur_status != 'IDLE'

      # use cookie in notes field to later check to avoid race conditions
      cookie = rand_str(8)
      tcms.update_caserun(job.case_run_id, {
        'notes' => cookie,
        'case_run_status' => TCMS::CASE_RUN_STATUS["RUNNING"]
      })

      # wait for any other concurrent updates to take place before we check if
      #   the test case run was reserved by us
      sleep 2
      updated = tcms.get_caserun_raw(job.case_run_id)
      return false if updated['notes'] != cookie
      job.notes = cookie
      job.case_run_status_id = updated['case_run_status_id']
      job.case_run_status = updated['case_run_status']
      job.running!

      return true
    end

    def current_job(test_case)
      job = ready_jobs.first
      if job.nil? || !job.running? || !job.matches?(test_case)
        raise "looks like a TCMS manager bug: #{job.inspect}, #{test_case.name}?!"
      end
      return job
    end

    def finished_jobs
      @finished_jobs ||= []
    end

    def ready_jobs
      @ready_jobs ||= []
    end

    def locked_jobs
      @locked_jobs ||= []
    end

    def non_runnable_jobs
      @non_runnable_jobs ||= []
    end

    # @return [Array[ExecutionUnit]>
    # @note TCMS_SPEC would be like "run:12356" or "caseruns:123,43,23"
    def incomplete_jobs
      return @incomplete_jobs if @incomplete_jobs

      job = ENV["TCMS_SPEC"] || opts[:tcms_spec]
      unless job
        raise "don't know what to execute, please specify TCMS execution specification in TCMS_SPEC"
      end
      type, garbage, items = job.partition(/s?:/)
      items = items.split(',').map { |i| Integer(i) }

      case type
      when "case"
        @incomplete_jobs = jobs_from_case_list(tcms.get_cases2(items))
      when "run"
        @incomplete_jobs =
          jobs_from_case_list(tcms.get_runs_cases(items))
      when "caserun"
        @incomplete_jobs = jobs_from_case_list(tcms.get_caseruns(items))
      end

      return @incomplete_jobs
    end


    # @param case_list [Array<Hash>] this basically takes cases from TCMS
    #   optionally intermixed with test case run fields
    def jobs_from_case_list(case_list)
      jobs = case_list.map { |c| TCMSTestCaseRun.new(c) }
      jobs.select! do |c|
        if c.runnable?
          true
        else
          non_runnable_jobs << c
          false
        end
      end
      return jobs
    end

    # represents the TCMS test case with list of scenario specifications to
    #   execute and status of everything related
    class TCMSTestCaseRun < OpenStruct
      attr_reader :overall_status

      def runnable?
        auto? && confirmed? && scenario_specification
      end

      def caserun?
        # must be populated when first loaded from TCMS_SPEC
        !! case_run_id
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def matches?(test_case)
        # fast match if we already own that scenario
        return true if cucumber_test_cases.any? { |c|
          c.location.to_s == test_case.location.to_s
        }

        # compare filename and scenario name
        if (test_case.location.file != scenario_specification[:file]) ||
          (
            test_case.keyword.length == "Scenario Outline".length &&
            test_case.source[-3].name != scenario_specification[:scenario_name]
          ) ||
          ( test_case.keyword.length == "Scenario".length &&
            test_case.name != scenario_specification[:scenario_name]
          )
            return false # surely we do not match
        end

        if test_case.keyword.length == "Scenario".length &&
            (
              scenario_specification[:example] ||
              scenario_specification[:examples_table]
            )
          # we expect an outline but have simple scenario
          Kernel.puts("case #{self.case_id} mismatch with scenario type, will never run")
          return false
        elsif test_case.keyword.length == "Scenario".length
          # single scenario to be run
          cucumber_test_cases << test_case
          @ready = true
          return true
        elsif scenario_specification[:example]
          # we want single example of outline to be run
          unless test_case.source.last.class.to_s.end_with?("::Row")
            Kernel.puts("case #{self.case_id} vs #{test_case.location.to_s}; cucumber API changed? Source is not a Row?")
            return false
          end

          if test_case.source.last.instance_variable_get(:@data) ==
              scenario_specification[:example]
            cucumber_test_cases << test_case
            @ready = true
            return true
          else
            return false
          end
        elsif scenario_specification[:examples_table]
          # we want a whole examples table to be run
          unless test_case.source.last.class.to_s.end_with?("::Row") &&
              test_case.source[-2].class.to_s =~ /::Examples(Table)?$/
            Kernel.puts("case #{self.case_id} vs #{test_case.location.to_s}; cucumber API changed?")
            return false
          end

          examples_table = test_case.source[-2]
          if examples_table.name == scenario_specification[:examples_table]
            cucumber_test_cases << test_case
            @ready = cucumber_test_cases.size == examples_table.example_rows.size
            return true
          else
            return false
          end
        elsif scenario_specification[:example].nil? &&
          scenario_specification[:examples_table].nil?
          # we want a whole outline to be run
          unless test_case.source.last.class.to_s.end_with?("::Row") &&
              test_case.source[-2].class.to_s =~ /::Examples(Table)?$/ &&
              test_case.source[-3].class.to_s.end_with?("ScenarioOutline")
            Kernel.puts("case #{self.case_id} vs #{test_case.location.to_s}; cucumber API changed?")
            return false
          end

          outline = test_case.source[-3]
          cucumber_test_cases << test_case
          @ready = cucumber_test_cases.size == test_case.source[-3].examples_tables.reduce(0) { |sum, t| sum + t.example_rows.size }
          return true
        else
          raise "we should never be here, #{self.case_id}, #{test_case.location.to_s}"
        end
      end

      def cucumber_test_cases
        @cucumber_test_cases ||= []
      end

      def cucumber_test_cases_completed
        @cucumber_test_cases ||= []
      end

      def next_cucumber_test_case
        if cucumber_test_cases.empty?
          raise "strange, case #{case_id} #next called but no more scenarios to run"
        end
        return cucumber_test_cases.first
      end

      def scenario_specification
        return @scenario_specification if defined?(@scenario_specification)

        @scenario_specification = nil

        if self.script.nil? || self.script.empty?
          Kernel.puts "Skipping #{self.case_id} with empty script."
          return nil
        end

        res = {}

        begin
          parsed_script = JSON.load(self.script)
          unless parsed_script["ruby"]
            Kernel.puts "Skipping #{self.case_id} with no ruby element."
            return nil
          end

          res[:file], nothing, res[:scenario_name] = parsed_script["ruby"].partition(':')

          # normalize file to hopefully match what's returned by cucumber
          unless res[:file].start_with?("features/", "private/")
            res[:file] = "features/" + res[:file]
          end

          if self.arguments && !self.arguments.empty?
            parsed_args = JSON.load(self.arguments)
            if !parsed_args.kind_of?(Hash)
              Kernel.puts "Skipping #{self.case_id} with faux arguments."
              return nil
            end
            if parsed_args.size == 1 && parsed_args.keys[0] == "Examples"
              res[:examples_table] = parsed_args.values[0]
            else
              res[:example] = parsed_args
            end
          end
        rescue => e
          Kernel.puts "Skipping #{self.case_id}: #{e}"
          return nil
        end

        @scenario_specification = res
        return res
      end

      def auto?
        self.is_automated != 0
      end

      def confirmed?
        self.case_status_id == 2
        #self.case_status == "CONFIRMED"
      end

      def ready?
        @ready
      end

      def running?
        return !!@running && !completed?
      end

      def executing!(test_case)
        # not sure we can do anything useful with this
      end

      def running!
        @running = true
      end

      # @param test_case [Cucumber::Core::Test::Case]
      def completed!(test_case)
        res = cucumber_test_cases.find { |tc| tc.location.to_s ==
                                              test_case.location.to_s}
        unless res
          raise "how on earth we were told test case is completed when we do not own it: #{test_case.location}"
        end

        # mostly for debugging record completed cases
        cucumber_test_cases_completed << test_case
        cucumber_test_cases.delete(res)
      end

      # FAILED cannot override ERROR, PASSED cannot override any other status
      def overall_status=(status)
        raise "unknown status #{status}" unless [ "PASSED", "FAILED", "ERROR" ].include?(status)

        case @overall_status
        when nil, "PASSED"
          @overall_status = status
        when "ERROR"
          # this status cannot be overriden
        when "FAILED"
          @overall_status = status if status != "PASSED"
        end
      end

      def completed?
        ready? && cucumber_test_cases.empty?
      end
    end
  end
end
