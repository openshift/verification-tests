Given /^I open ocm portal with #{WORD}$/ do |usertype|
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR
  portals = YAML.load_file(expand_private_path("config/credentials/ocm.yaml"))
  ocm_env = env.ocm_env
  base_url = env.web_console_url
  step "I have a browser with:", table(%{
    | rules        | lib/rules/web/ocm_console/ |
    | base_url     | #{base_url}                |
    | snippets_dir | #{snippets_dir}            |
  })
  if ocm_env == "stage"
    browser.run_action(:goto_ocm_stage_console)
  elsif ocm_env == "product"
    browser.run_action(:goto_ocm_prod_console)
  end
  @result = browser.run_action(:login_ocm_sequence,
                               username: portals[ocm_env]["users"][usertype]["username"],
                               password: portals[ocm_env]["users"][usertype]["password"])
end