Given /^I open ocm portal with #{WORD}$/ do |usertype|
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR
  portals = YAML.load_file(expand_private_path("config/credentials/ocm.yaml"))
  base_url = env.web_console_url
  step "I have a browser with:", table(%{
    | rules        | lib/rules/web/ocm_console/ |
    | base_url     | #{base_url}                |
    | snippets_dir | #{snippets_dir}            |
  })
  if ENV['BUSHSLICER_DEFAULT_ENVIRONMENT'] == "ocm_stage"
    ocm_env = "stage"
  elsif ENV['BUSHSLICER_DEFAULT_ENVIRONMENT'] == "ocm_prod"
    ocm_env = "product"
  end
  if portals[ocm_env]["users"][usertype] != nil
    loginname = portals[ocm_env]["users"][usertype]["username"]
    loginpassword = portals[ocm_env]["users"][usertype]["password"]
  else
    loginname = env.static_user(usertype).loginname
    loginpassword = env.static_user(usertype).password
  end
  browser.browser.goto base_url
  @result = browser.run_action(:login_ocm_sequence,
                               username: loginname,
                               password: loginpassword)
end
