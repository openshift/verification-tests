Given /^I open ocm #{WORD} portal with #{WORD}$/ do |envi, usertype|
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR + "/base/"
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR
  portals = YAML.load_file(expand_private_path("config/credentials/ocm.yaml"))
  portal_name = envi
  base_url = portals[portal_name]["url"]
  step "I have a browser with:", table(%{
    | rules        | #{base_rules}                      |
    | rules        | lib/rules/web/ocm_console/  |
    | base_url     | #{base_url}       |
    | snippets_dir | #{snippets_dir}                    |
  })
  @result = browser.run_action(:login_ocm_stage_console,
                               username: portals[portal_name]["users"][usertype]["username"],
                               password: portals[portal_name]["users"][usertype]["password"])
end

When /^I perform the :(.*?) page action$/ do |action|
  @result = browser.run_action(action)
end

Given /^I create a ([^\s]*) ?OSD cluster (.*?)$/ do |machineType, clusterName|
  if machineType != ""
    @result = browser.run_action(:create_osd_cluster,
    cluster_name: clusterName,
    machine_type: machineType)
  else
    @result = browser.run_action(:create_osd_cluster,
    cluster_name: clusterName)
  end
end