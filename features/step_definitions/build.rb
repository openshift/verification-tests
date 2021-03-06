Given /^the #{QUOTED} build was created(?: within #{NUMBER} seconds)?$/ do |build_name, timeout|
  transform binding, :build_name, :timeout
  timeout = timeout ? Integer(timeout) : 60
  @result = build(build_name).wait_to_appear(user, timeout)

  unless @result[:success]
    raise "build #{build_name} never created"
  end
end

# success when build finish regardless of completion status
Given /^the #{QUOTED} build finishe(?:d|s)(?: within #{NUMBER} seconds)?$/ do |build_name, timeout|
  transform binding, :build_name, :timeout
  wait_timeout = timeout ? Integer(timeout) : 60*15
  @result = build(build_name).wait_till_finished(user, wait_timeout)

  unless @result[:success]
    raise "build #{build_name} never finished"
  end
end

# success if build completed successfully
Given /^the #{QUOTED} build complete(?:d|s)(?: within #{NUMBER} seconds)?$/ do |build_name, timeout|
  transform binding, :build_name, :timeout
  wait_timeout = timeout ? Integer(timeout) : 60*15
  @result = build(build_name).wait_till_completed(user, wait_timeout)

  unless @result[:success]
    if [:failed, :error].include? @result[:matched_status]
      user.cli_exec(:logs, resource_name: "build/#{build_name}")
      raise "build #{build_name} failed"
    end
    raise "build #{build_name} never completed"
  end
end

# success if build completed with a failure
Given /^the #{QUOTED} build fail(?:ed|s)(?: within #{NUMBER} seconds)?$/ do |build_name, timeout|
  transform binding, :build_name, :timeout
  wait_timeout = timeout ? Integer(timeout) : 60*15
  @result = build(build_name).wait_till_failed(user, wait_timeout)

  unless @result[:success]
    raise "build #{build_name} completed with success or never finished"
  end
end

# success if build was cancelled
Given /^the #{QUOTED} build was cancelled(?: within #{NUMBER} seconds)?$/ do |build_name, timeout|
  transform binding, :build_name, :timeout
  wait_timeout = timeout ? Integer(timeout) : 60*15
  @result = build(build_name).wait_till_cancelled(user, wait_timeout)

  unless @result[:success]
    raise "build #{build_name} was not canceled"
  end
end

Given /^the #{QUOTED} build (becomes|is) #{SYM}(?: within #{NUMBER} seconds)?$/ do |build_name, mode, status, timeout|
  transform binding, :build_name, :mode, :status, :timeout
  if mode == "becomes"
    wait_time_out = timeout ? Integer(timeout) : 60*10
    @result = build(build_name).wait_till_status(status.to_sym, user, wait_time_out)
    unless @result[:success]
      raise "build #{build_name} never became #{status}"
    end
  elsif mode == "is"
    @result = build(build_name).status?(user: user, status: status.to_sym)
    unless @result[:success]
      raise "build #{build_name} current status is not  #{status}"
    end
  end
end
# the build can be any of the status in the table
Given /^the #{QUOTED} build status is any of:$/ do |build_name, table|
  transform binding, :build_name, :table
  status = table.raw.flatten
  status.map! {|x| x.to_sym }
  @result = build(build_name).status?(user: user, status: status)
  unless @result[:success]
    raise "build #{build_name} current status is not any of: #{status}"
  end
end
Then(/^I save pruned builds in the #{QUOTED} project into the #{SYM} clipboard$/) do |project_name, cb_name|
  project = self.project(project_name)
  # lookbehind does not support quantifiers and jruby no support of \K
  build_names = @result[:response].scan(%r%(?<=^#{Regexp.escape(project.name)})\s+[^\s]*$%)
  builds = build_names.map { |bn|
    BushSlicer::Build.new(name: bn.strip, project: project)
  }
  cb[cb_name] = builds
end

Given /^I save project builds into the #{SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  cb[cb_name] = project.get_builds(by: user)
end

Then /^the project should contain no builds$/ do
  builds = project.get_builds(by: user)
  unless builds.empty?
    raise "#{builds.size} builds present in the #{project.name} project"
  end
end
