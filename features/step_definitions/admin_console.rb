# Given /^default admin-console route is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
#   cb_name ||= :console
#   cb[cb_name] = route('console', service('console',project('openshift-console', switch: false))).dns(by: admin)
# end

Given /^I open admin console in a browser$/ do
  base_rules = VerificationTests::WebConsoleExecutor::RULES_DIR + "/base/"
  snippets_dir = VerificationTests::WebConsoleExecutor::SNIPPETS_DIR

  version = env.webconsole_executor.get_master_version(user, via_rest: true)

  step "I have a browser with:", table(%{
    | rules        | #{base_rules}                            |
    | rules        | lib/rules/web/admin_console/base/        |
    | rules        | lib/rules/web/admin_console/#{version}/  |
    | base_url     | <%= env.web_console_url %>               |
    | snippets_dir | #{snippets_dir}                          |
  })
  @result = browser.run_action(:login,
                               username: user.auth_name,
                               password: user.password)
  raise "cannot login to web console" unless @result[:success]
  @result = browser.run_action(:click_console_selector)
  raise "cannot click user dropdown menu" unless @result[:success]
  # we need to open in same tab and I don't know a better way
  # console_url = browser.browser.a(text: "Cluster Console").href
  # browser.browser.goto console_url
  browser.browser.a(text: "Cluster Console").click
  @result = browser.run_action(:login_admin_console,
                               username: user.auth_name,
                               password: user.password)
  raise "cannot login to cluster console" unless @result[:success]
  browser.base_url = browser.url.sub(%r{(https://[^/]+/).*}, "\\1")
end
