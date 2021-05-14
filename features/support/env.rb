## add our lib dir to load path
$LOAD_PATH << File.expand_path("#{__FILE__}/../../../lib")

if Gem::Version.new("2.3") > Gem::Version.new(RUBY_VERSION)
  raise "Ruby version earlier than 2.3 not supported"
end
if Cucumber::VERSION.split('.')[0].to_i < 2
  raise "Cucumber version < 2 not supported"
end

SkipBushSlicerManagerDefault = true # should manager.rb skip setting Manager

require 'common' # common code
require 'world' # our custom bushslicer world
require 'log' # BushSlicer::Logger
require 'manager' # our shared global state
require 'debug'

## default course of action would be to update BushSlicer files when
#  changes are needed but some features are specific to team and test
#  environment; lets allow customizing base classes by loading a separate
#  project tree
private_env_rb = File.expand_path(BushSlicer::PRIVATE_DIR + "/env.rb")
require private_env_rb if File.exist? private_env_rb

World do
  # the new object created here would be the context Before and After hooks
  # execute in. So extend that class with methods you want to call.
  BushSlicer::World.new
end

## while we can move everything inside World, lets try to outline here the
#    basic steps to have world ready to execute scenario
Before do |_scenario|
  if manager.skip_scenario? _scenario
    manager.skip_scenario_done _scenario
    skip_this_scenario "Scenario skipped by Test Case Manager"
    next
  end

  setup_logger
  logger.info("=== Before Scenario: #{_scenario.name} ===")
  localhost.chdir
  self.scenario = _scenario

  begin
    ## raise inside block only if error can affect scenarios execution ##
    # put other calls here to setup world according to tags, etc.
    prepare_scenario_users
  rescue => err
    logger.error err
    quit_cucumber
    raise err
  ensure
    manager.test_case_manager.signal(:finish_before_hook, scenario, err)
    logger.info("=== End Before Scenario: #{_scenario.name} ===")
    # dedup from before to after hook is tricky, leaving for later
    # logger.dedup_start
  end
end

## while we can move everything inside World, lets try to outline here the
#    basic steps that are run after each scenario execution
After do |_scenario|
  if _scenario.respond_to?(:test_case_manager_skip?)
    next
  end

  # logger.dedup_flush
  logger.info("=== After Scenario: #{_scenario.name} ===")
  self.scenario = _scenario # this is different object than in Before hook

  debug_in_after_hook

  begin
    ## raise inside block only if error can affect next scenarios execution ##
    # Manager will call clean-up including self.after_scenario
    manager.after_scenario
  rescue => err
    logger.error err # make sure we capture it with the custom HTTP logger
    quit_cucumber
    raise err
  ensure
    logger.info("=== End After Scenario: #{_scenario.name} ===")
    BushSlicer::Logger.reset_runtime # avoid losing output from test case mngr
    manager.test_case_manager.signal(:finish_after_hook, scenario, err)
  end
end

AfterStep do |scenario|
  # logger.dedup_flush
  # logger.dedup_start
end

AfterConfiguration do |config|
  BushSlicer::Common::Setup.handle_signals
  BushSlicer::Common::Setup.set_bushslicer_home

  ## use default classes if these were not overriden by private ones
  BushSlicer::Manager ||= BushSlicer::DefaultManager
  BushSlicer::World   ||= BushSlicer::DefaultWorld

  ## install step failure debugging code
  if BushSlicer::Manager.conf[:debug_failed_steps]
    BushSlicer::Debug.step_fail_cucumber2
  end

  ## set test case manager and scenario filter if requested
  BushSlicer::Manager.instance.setup_for_test_run(config)
end

at_exit do
  BushSlicer::Logger.reset_runtime # otherwise we lose output
  BushSlicer::Manager.instance.logger.info("=== At Exit ===")
  BushSlicer::Manager.instance.test_case_manager.signal(:at_exit)
  BushSlicer::Manager.instance.at_exit
end
