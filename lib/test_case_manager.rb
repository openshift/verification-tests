require 'thread' # for the uploader thread
require 'tmpdir'
require 'fileutils'
require 'find'

require 'common'

# since internal s3 will be de commissioned, we set the ENV['USE_SCP_SERVER'] to true so instead of setting it externally
ENV['USE_SCP_SERVER'] = '1'

module BushSlicer
  # generic test case manager that delegates to specific test case management
  #   system test suite class
  class TestCaseManager
    include Common::Helper
    include Common::Hacks

    attr_reader :opts, :test_suite

    def initialize(**opts)
      @opts = opts

      @test_suite = BushSlicer.const_get(opts[:test_suite_class]).
                                            new(**opts[:test_suite_opts])

      @attach_queue = Queue.new
      @attacher = Thread.new do
        while workitem = @attach_queue.pop # yes, assignment
          handle_attach(workitem)
        end
      end
    end

    ############ test case manager interface methods ############

    # act according to signal from BushSlicer
    #   job == TCMS test case == some set of Cucumber scenarios/test cases
    #   test case == Cucumber scenario
    # @note see [TCMSTestCaseRun#overall_status=] for how status works
    def signal(signal, *args)
      fix_require_lock # see method in Common::Hacks

      case signal
      when :end_of_cases
      when :start_case
        test_case = args[0]
        test_suite.test_case_execute_start!(test_case)
      when :end_case
        finish_event = args[0]
        attachments = handle_current_artifacts(test_suite.artifacts_format)
        test_suite.test_case_execute_finish!(finish_event, attach: attachments)
        reset_hooks_status
      when :skip_case
        test_suite.current_test_record = nil unless test_suite.current_test_record.nil?
      when :finish_before_hook
        test_case = args[0]
        err = args[1]
        if err
          test_suite.test_case_failed_before!(test_case)
          @before_failed = true
        end
      when :finish_after_hook
        test_case = args[0]
        err = args[1]
        if err
          test_suite.test_case_failed_after!(test_case)
          @after_failed = true
        end
      when :at_exit
        if test_suite.incomplete?
          test_suite.executed.each do |job|
            Kernel.puts("#{job.human_id} - executed")
          end
          test_suite.disowned.each do |job|
            Kernel.puts("#{job.human_id} - already reserved")
          end
          test_suite.incomplete.each do |job|
            Kernel.puts("#{job.human_id} - could not find scenario, or scenario not suitable for current TEST_MODE")
          end
          test_suite.non_runnable.each do |job|
            Kernel.puts("#{job.human_id} - not runnable")
          end
          test_suite.pending.each do |job|
            Kernel.puts("#{job.test_case_id} - process quit before we executed")
          end
        end

        ## let attacher know we finish and wait for queue drain
        @attach_queue << false
        wait_for_attacher
        unless @artifacts_filer.is_a? BushSlicer::Amz_EC2
          @artifacts_filer.clean_up if @artifacts_filter
        end
      end
    end

    def after_failed?
      @after_failed
    end

    def before_failed?
      @before_failed
    end

    def reset_hooks_status
      @after_failed = false
      @before_failed = false
    end

    # @param test_case [Cucumber::Core::Test::Case]
    def push(test_case)
      test_suite.test_case_push(test_case)
    end

    # return next cucumber test_case to be executed and sets status to RUNNING
    # @note redundant with Cucumber 5.3 integration
    # def next
    #   test_suite.test_case_next!
    # end

    # we commit to executing a test case
    # @return [Boolean] whether we do or reject for whatever reason
    def commit!(test_case)
      test_suite.commit!(test_case)
    end

    # @return [Enumerator<Cucumber::Core::Test::Case>] the remaining pending
    #   Cucumber test cases (does not include current test record)
    # @yields [Enumerator<Cucumber::Core::Test::Case>]
    def all_cucumber_test_cases(*args, &block)
      test_suite.all_cucumber_test_cases(*args, &block)
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

    def artifacts_relative_path
      File.join(*TIME_SUFFIX)
    end

    def artifacts_base_url
      if ENV['USE_SCP_SERVER']
        File.join(
          conf[:services, :artifacts_file_server, :url],
          artifacts_relative_path
        )
      else # s3
        # we can generate in the framework with the resulting URL valid only 7
        # days, or use the proxy presigned_url generator web service which
        # generates a new url each time.  Set environment variable
        # GEN_DATA_HUB_URL to use the framework approach
        unless ENV['GEN_DATA_HUB_URL']
          File.join(
            conf[:services, :"DATA-HUB", :url_generator_endpoint],
            conf[:services, :"DATA-HUB", :generator_controller_path]
          )
        else
          File.join(
            conf[:services, :"DATA-HUB", :endpoint],
            conf[:services, :"DATA-HUB", :bucket_name]
          )
        end
      end
    end

    def artifacts_base_remote_path
      if ENV['USE_SCP_SERVER']
        remote_path = File.join(
          conf[:services, :artifacts_file_server, :upload_path],
          artifacts_relative_path
        )
      else
        remote_path = File.join(
          "logs/", artifacts_relative_path)
      end
    end

    # @return [Array<String>] list of attached artifacts URLs for a dir
    def artifacts_urls(dir)
      urls = []
      if ENV['USE_SCP_SERVER']
        dirchars = dir.length + ( dir.end_with?("/","\\") ? 0 : 1 )
        Find.find(dir) do |file|
          if File.file? file
            urls << File.join(artifacts_base_url, File.basename(dir), file[dirchars..-1])
          end
        end
      else # s3 object
        if ENV['GEN_DATA_HUB_URL']
          dhub = BushSlicer::Amz_EC2.new(service_name: "DATA-HUB")
          urls << dhub.s3_generate_url(key: File.join(artifacts_base_remote_path, File.basename(dir)))
        else
          object_key = artifacts_base_remote_path + "/" + File.basename(dir)
          logger.info("obj_key: #{object_key}")
          url = artifacts_base_url +  object_key
          logger.info("URL: #{url}")
          urls << url
        end
      end
      return urls
    end

    # executed from within the attacher thread to actually upload/attach log;
    def handle_attach(dir)
      if ENV['USE_SCP_SERVER']
        begin
          ## upload files
          artifacts_filer.mkdir artifacts_base_remote_path, raw: true
          artifacts_filer.copy_to(dir, artifacts_base_remote_path, raw: true)
        rescue => e
          Kernel.puts exception_to_string(e)
        ensure
          FileUtils.remove_entry dir
        end
      else
        # this is a Aws_EC2 instance
        bucket_name = conf['services', 'DATA-HUB', 'bucket_name']
        key = artifacts_filer.upload_cucushift_html(bucket_name: bucket_name,
          local_log: dir, dst_base_path: artifacts_base_remote_path)
        logger.info("HTML log uploaded to #{bucket_name} with key #{key}")
      end
    end

    # @param job [TCMSTestCase]
    # @param test_case [Cucumber::Core::Test::Case]
    # @note to avoid upload/attaching delay, perform rsync and attach within
    #   a thread
    def handle_current_artifacts(format)
      if format.nil?
        return []
      elsif format != :urls
        raise "we only support :urls format of artifacts"
      end

      # find out what to attach
      urls = []
      manager.custom_formatters.each do |formatter|
        ## move artifacts to a separate dir
        dir = formatter.process_scenario_log(after_failed: after_failed?,
                                             before_failed: before_failed?)
        unless dir
          logger.warn "Formatter dir not set, bug in formatter of test case could not be run"
          next
        end

        urls.concat artifacts_urls(dir)
        if urls.empty?
          if Dir.empty?(dir)
            logger.warn "Formatter artifacts dir empty '#{dir}'."
          else
            logger.warn "Failed to obtain artifact URLs from dir '#{dir}'."
          end
        end
        @attach_queue << dir
        # to test attach in main thread use this:
        # handle_attach(dir)
      end

      return urls
    end

    # @return [BushSlicer::Host] of the server storing logs and artifacts
    def artifacts_filer
      @artifacts_filer if @artifacts_filer
      if ENV['USE_SCP_SERVER']
        @artifacts_filer = BushSlicer.
          const_get(conf[:services, :artifacts_file_server, :host_type]).
          new(
            conf[:services, :artifacts_file_server, :hostname],
            **conf[:services, :artifacts_file_server]
          )
      else
        @artifacts_filer = BushSlicer::Amz_EC2.new(service_name: "DATA-HUB")
      end
      return @artifacts_filer
    end
  end
end
