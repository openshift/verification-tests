Given /^I open accountant console in a browser$/ do
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR + "/base/"
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR

  step "evaluation of `env.web_console_url[/(?<=\\.).*(?=\.openshift)/]` is stored in the :acc_console_url clipboard"
  step "I have a browser with:", table(%{
    | rules        | #{base_rules}                      |
    | rules        | lib/rules/web/accountant_console/  |
    | base_url     | <%= env.web_console_url %>         |
    | snippets_dir | #{snippets_dir}                    |
  })
  @result = browser.run_action(:login_acc_console,
                               username: user.auth_name,
                               password: user.password)
  raise "cannot login to web console" unless @result[:success]
  @result = browser.run_action(:click_user_dropdown)
  raise "cannot click user dropdown menu" unless @result[:success]
  # we need to open in same tab and I don't know a better way
  # this bug should not block all tests https://bugzilla.redhat.com/show_bug.cgi?id=1572838
  # console_url = browser.browser.a(text: "Manage Account").href
  console_url = cb.acc_console_url.sub("online-", "https://manage.") + ".openshift.com"
  browser.browser.goto console_url
  @result = browser.run_action(:navigate_to_subscription)
  raise "cannot navigate to subscription page" unless @result[:success]
  browser.base_url = browser.url.sub('/index', '/')
end

When /^accountant console cluster resource quota is set to:$/ do |table|
  transform binding, :table
  step 'I perform the :goto_resource_settings_page web action with:', table
  step 'the step should succeed'
  step 'I perform the :set_resource_amount_by_input_and_update web action with:', table
  step 'the step should succeed'
end

