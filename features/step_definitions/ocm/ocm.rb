Given /^I open ocm portal as an? #{WORD} user$/ do |usertype|
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR
  base_url = env.web_console_url
  step "I have a browser with:", table(%{
    | rules        | lib/rules/web/ocm_console/ |
    | base_url     | #{base_url}                |
    | snippets_dir | #{snippets_dir}            |
  })
  if ocm_env == "stage"
    browser.run_action(:goto_ocm_console)
  elsif ocm_env == "product"
    browser.run_action(:goto_ocm_console)
  end
  @result = browser.run_action(:login_ocm_sequence,
                               username: env.static_user(usertype).loginname,
                               password: env.static_user(usertype).password)
end
