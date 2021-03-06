# Use this step to register clean up steps to be executed in the AfterHook
#   regardless of scenario success status.
# Clean-up steps are registered in reverse order to make first step execute
#   first as test developer would expect. Still separate register step
#   invocations will execute in reverse order as designed. We in general run
#   clean-up steps in reverse order so that environment for resource clean-up
#   is same as on creation.
# see #to_step_procs
Then /^I register clean\-up steps:$/ do |table|
  transform binding, :table
  teardown_add *to_step_procs(table)
end

# clean-up steps executed when clipboard is `nil` or `false`
Given /^I register skippable clean\-up steps based on the #{SYM} clipboard:$/ do |cb_name, table|
  transform binding, :cb_name, :table
  _procs = to_step_procs(table)
  teardown_add {_procs.reverse_each(&:call) unless cb[cb_name]}
  # teardown_add *to_step_procs(table).map{|p| proc {p.call unless cb[cb_name]}}
end

# put usually at beginning of scenario to execute env consistency checks
# and then those checks will be execute as last clean-up to check env is back up
# @note one issue here is that transformation will take place when defining
#   steps, so you may need the step `the expression should be true>` as a
#   workaround
Then /^system verification steps are used:$/ do |table|
  transform binding, :table
  steps = to_step_procs(table)
  steps.reverse_each { |s| s.call }
  teardown_add *steps
end

# repeat steps specified in a multi-line string until they pass (that means
#   until they execute without raising an error)
Given /^I wait(?: up to #{NUMBER} seconds)? for the steps to pass:$/ do |seconds, steps_string|
  transform binding, :seconds, :steps_string
  begin
    unless steps_string.respond_to? :lines
      # we are using a table instead of multi-line string it seems
      steps_string = steps_string.raw.flatten.join("\n")
    end
    logger.dedup_start
    seconds = Integer(seconds) rescue 60
    # repetitions = 0
    error = nil
    success = wait_for(seconds) {
      # repetitions += 1
      # this message needs to be disabled as it defeats deduping
      # logger.info("Beginning step repetition: #{repetitions}")
      begin
        steps steps_string
        true
      rescue => e
        error = e
        false
      end
    }

    raise error unless success
  ensure
    logger.dedup_flush
  end
end

# note that when steps started before time limit was reached, if they take
# more time to complete than the limit, total execute time will be longer
Given /^I repeat the steps up to #{NUMBER} seconds:$/ do |seconds, steps_string|
  transform binding, :seconds, :steps_string
  begin
    logger.dedup_start
    seconds = Integer(seconds)
    error = nil
    wait_for(seconds) {
      steps steps_string
      false
    }
  ensure
    logger.dedup_flush
  end
end

# repeat steps x times in a multi-line string
Given /^I run the steps #{NUMBER} times:$/ do |num, steps_string|
  transform binding, :num, :steps_string
  eval_regex = /\#\{(.+?)\}/
  eval_found = steps_string =~ eval_regex
  begin
    logger.dedup_start
    (1..Integer(num)).each { |i|
      cb.i = i
      if eval_found
        steps steps_string.gsub(eval_regex) { |s| "<%= #{$1} %>"}
      else
        steps steps_string
      end
    }
  ensure
    logger.dedup_flush
  end
end

# repeat steps with the values from a clipboard
# Example in scenario 'Loop over the clipboard'
Given /^I repeat the following steps for each #{SYM} in cb\.([\w]+):$/ do |varname, cbsym, steps_str|
  transform binding, :varname, :cbsym, :steps_str
  eval_regex = /\#\{(.+?)\}/
  eval_found = steps_str =~ eval_regex
  begin
    logger.dedup_start
    cb[cbsym].each { |x|
      cb[varname] = x
      if eval_found
        steps steps_str.gsub(eval_regex) { |s| "<%= #{$1} %>"}
      else
        steps steps_str
      end
    }
  ensure
    logger.dedup_flush
  end
end

