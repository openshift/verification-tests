require 'webauto/webconsole_executor'
Given /^I open ocm portal as an? #{WORD} user$/ do |usertype|
  transform binding, :usertype
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR
  base_url = env.web_console_url
  step "I have a browser with:", table(%{
    | rules        | lib/rules/web/ocm_console/ |
    | base_url     | #{base_url}                |
    | snippets_dir | #{snippets_dir}            |
  })
  browser.browser.goto base_url
  @result = browser.run_action(:login_ocm_sequence,
                               username: env.static_user(usertype).loginname,
                               password: env.static_user(usertype).password)
end
