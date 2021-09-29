# Given /^default admin-console route is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
#   cb_name ||= :console
#   cb[cb_name] = route('console', service('console',project('openshift-console', switch: false))).dns(by: admin)
# end

Given /^default admin-console downloads route is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
  ensure_admin_tagged
  cb_name ||= :downloads_route
  cb[cb_name] = route('downloads', service('downloads',project('openshift-console', switch: false))).dns(by: admin)
end

Given /^I open admin console in a browser$/ do
  ensure_console_tagged
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR + "/base/"
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR

  version = env.webconsole_executor.get_master_version(user, via_rest: true)
  step "I have a browser with:", table(%{
    | rules        | lib/rules/web/admin_console/#{version}/  |
    | rules        | #{base_rules}                            |
    | rules        | lib/rules/web/admin_console/base/        |
    | base_url     | <%= env.admin_console_url %>             |
    | snippets_dir | #{snippets_dir}                          |
  })
  browser.run_action(:goto_admin_console_root)
  @result = browser.run_action(:login_admin_console,
                               username: user.auth_name,
                               password: user.password,
                               idp: env.idp)
  raise "cannot login to cluster console" unless @result[:success]
  step "I run the :navigate_to_admin_console web action"
  browser.base_url = browser.url.sub(%r{(https://[^/]+/).*}, "\\1")
end

Given /^I open admin console in a browser with:$/ do |table|
  ensure_console_tagged
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR + "/base/"
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR

  version = env.webconsole_executor.get_master_version(user, via_rest: true)
  step "I have a browser with:", table(%{
    | rules        | lib/rules/web/admin_console/#{version}/  |
    | rules        | #{base_rules}                            |
    | rules        | lib/rules/web/admin_console/base/        |
    | base_url     | <%= env.admin_console_url %>             |
    | snippets_dir | #{snippets_dir}                          |
  })
  browser.run_action(:goto_admin_console_root)
  params = opts_array_to_hash(table.raw)
  @result = browser.run_action(:login_sequence,
                               username: params[:user],
                               password: params[:password],
                               idp: params[:idp])
end
