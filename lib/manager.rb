require 'singleton'

require 'log'
require 'configuration'
require 'environment_manager'
# should not require 'common'

module BushSlicer
  # @note this class allows accessing global test execution state.
  #       Get the singleton object by calling Manager.instance.
  #       Manager should point always at the correct manager implementation.
  class DefaultManager
    include Singleton
    attr_accessor :world
    attr_reader :temp_resources, :test_case_manager, :custom_formatters, :cucumber_config
    attr_writer :ast_lookup

    def initialize
      @world = nil
      @temp_resources = []

      # # @browsers = ...

      # keep reference to BushSlicer custom formatters so we can interact;
      #   at the moment we use to call #process_scenario_log from the test case
      #   manager to get hold on scenario log and artifacts at convenient time
      @custom_formatters = []
    end

    def clean_up
      if @world
        begin
          # this is likely not going to work in at_exit pahse with
          # cucumber 2.4 because builtin methods like `#step` are messed up
          # at that stage. Should we continue on failures in `#at_exit`?
          @world.after_scenario
        ensure
          # let GC kick in as well avoid double clean-up at_exit
          @world = nil
        end
      end
      @environments.clean_up if @environments
      @temp_resources.each(&:clean_up)
      @temp_resources.clear
      Host.localhost.clean_up
    end
    alias after_scenario clean_up

    def at_exit
      # test_case_manager.at_exit # call in env.rb for visibility

      # perform clean up in case of abrupt interruption (ctrl+c)
      #   duplicate call after proper clean up in After hook should not hurt
      clean_up
    end

    def environments
      @environments ||= EnvironmentManager.new
    end

    def logger
      @logger ||= Logger.new
    end

    def conf
      @conf ||= Configuration.new
    end

    def self.conf
      self.instance.conf
    end

    def setup_for_test_run(cucumber_config)
      @cucumber_config = cucumber_config
      init_test_case_manager(cucumber_config)
    end

    def ast_lookup
      unless @ast_lookup
        @ast_lookup = custom_formatters.find { |f|
          f.respond_to? :ast_lookup
        }&.ast_lookup
        unless @ast_lookup
          unless cucumber_config
            raise "to have an AstLookup, you must run under Cucumber and properly call #setup_for_test_run first"
          end
          require 'cucumber/formatter/ast_lookup'
          @ast_lookup = ::Cucumber::Formatter::AstLookup.new(cucumber_config)
        end
      end
      @ast_lookup
    end

    def skip_scenario!(scenario)
      @skip_scenario = scenario
    end

    def skip_scenario?(scenario)
      if @skip_scenario
        if @skip_scenario == scenario
          true
        else
          raise "instructed to skip scenario #{@skip_scenario} but was asked about #{scenario}"
        end
      end
    end

    def skip_scenario_done(scenario)
      if @skip_scenario
        if @skip_scenario == scenario
          @skip_scenario = nil
        else
          raise "instructed to skip scenario #{@skip_scenario} but was notified about skipping #{scenario}"
        end
      else
        raise "no scenario to skip but was notified about skipping #{scenario}"
      end
    end

    def init_test_case_manager(cucumber_config)
      tc_mngr = ENV['BUSHSLICER_TEST_CASE_MANAGER'] || conf[:test_case_manager]
      tc_mngr = tc_mngr ? tc_mngr + '_tc_manager' : false
      if tc_mngr
        logger.info("Using #{tc_mngr} test case manager")
        tc_mngr_obj = conf.get_optional_class_instance(tc_mngr)

        ## register our test case manager
        @test_case_manager = tc_mngr_obj

        ## add our test case manager notifyer to the filter chain
        require 'test_case_manager_filter'
        cucumber_config.filters << TestCaseManagerFilter.new(tc_mngr_obj)
      else
        # dummy test case manager to avoid no method defined errors
        @test_case_manager = Class.new do
          def method_missing(m, *args, &block); end
        end.new
      end
    end
  end

  # allow seamless use of manager outside Cucumber
  unless defined?(SkipBushSlicerManagerDefault) && SkipBushSlicerManagerDefault
    Manager ||= DefaultManager
  end
end
