# you use "second", "third", "default", etc. user
Given /^I switch to(?: the)? #{WORD} user$/ do |who|
  user(word_to_num(who))
end

# user full or short service account name, e.g.:
# system:serviceaccount:project_name:acc_name
# acc_name
Given /^I switch to the (.+) service account$/ do |who|
  @user = service_account(who)
end

Given /^I switch to cluster admin pseudo user$/ do
  ensure_admin_tagged
  @user = admin
end

Given /^I create the serviceaccount "([^"]*)"$/ do |name|
  sa = service_account(name)
  @result = sa.create(by: user)

  raise "could not create service account #{name}" unless @result[:success]
end

Given /^I find a bearer token of the(?: (.+?))? service account$/ do |acc|
  service_account(acc).load_bearer_tokens(user: user)
  if service_account(acc).cached_tokens == []
    # Starting with kube 1.24, i.e. OCP 4.11, serviceaccount's YAML does not have an automatically-generated secret-based token
    # So we explicitly create token here
    acc = service_account(acc).name if acc.include? ":" # when the arg uses format "system:serviceaccount:projectname:default"
    @result = user.cli_exec(:create_token, [[:serviceaccount, acc]])
    raise "Could not create token for the serviceaccount #{acc}" unless @result[:success]
    service_account(acc).add_str_token(@result[:response], protect: true)
  end
end

Given /^the(?: ([a-z]+))? user has all owned resources cleaned$/ do |who|
  num = who ? word_to_num(who) : nil
  user(num).clean_up_on_load
end

Given /^(I|admin) ensures identity #{QUOTED} is deleted$/ do |by, name|
  _user = by == "admin" ? admin : user
  _resource = identity(name)
  _seconds = 60
  @result = _resource.ensure_deleted(user: _user, wait: _seconds)
end

Given /^I restore user's context after scenario$/ do
  @result = user.cli_exec(:config, subcommand: "current-context")
  raise "could not get current-context" unless @result[:success]

  _current_context = @result[:response].strip
  _user = user

  teardown_add {
    _user.cli_exec(:config_use_context, name: _current_context)
  }
end

Given /^I save kube config in file #{QUOTED}$/ do |path|
  view_opts = { output: "yaml", minify: true, flatten: true }
  @result = user.cli_exec(:config_view, **view_opts, _quiet: true)
  unless @result[:success]
    raise "Failed to save kube config in file #{path}"
  end
  FileUtils::mkdir_p File::dirname(path.strip)
  File.write(path.strip, @result[:response])
end

