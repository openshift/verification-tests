When /^I perform the :(.*?) web( console)? action with:$/ do |action, console, table|
  transform binding, :action, :console, :table
  if console
    # OpenShift web console actions should not depend on last used browser but
    #   current user we are switched to
    cache_browser(user.webconsole_executor)
    @result = user.webconsole_exec(action.to_sym, opts_array_to_hash(table.raw))
  else
    @result = browser.run_action(action.to_sym, **opts_array_to_hash(table.raw))
  end
end

#run web action without parameters
When /^I run the :(.+?) web( console)? action$/ do |action, console|
  transform binding, :action, :console
  if console
    cache_browser(user.webconsole_executor)
    @result = user.webconsole_exec(action.to_sym)
  else
    @result = browser.run_action(action.to_sym)
  end
end

# @precondition a `browser` object
When /^I access the "(.*?)" (?:path|url) in the web (?:console|browser)$/ do |url|
  transform binding, :url
  @result = browser.handle_url(url)
end

Given /^I login via web console$/ do
  cache_browser(user.webconsole_executor)
  @result = env.webconsole_executor.login(user)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{user.name} login via web console failed"
  end
end

Given /^I logout via web console$/ do
  env.webconsole_executor.logout(user)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{user.name} logout via web console failed"
  end
end

Given /^the (.*) user is using same web console browser as (.*)$/ do |who, from_who|
  transform binding, :who, :from_who
  new_user = user(word_to_num(who))
  base_user = user(word_to_num(from_who))
  env.webconsole_executor.set_executor_for_user(new_user, base_user.webconsole_executor)
end


# @author cryan@redhat.com
# @params the table is to be populated with values from the initialization
# method in the web4cucumber.rb file. Below, you will see samples from rules
# and base_url, but other values can be added also.
# @notes this creates a separate browser instance, different from the console
# browser previously used. Use this step for non-console cases.
# *NOTE* be sure to include the protocol before the base URL in your table,
# for example, http:// or https://, otherwise this will generate a URI error.
Given /^I have a browser with:$/ do |table|
  transform binding, :table
  init_params = opts_array_to_hash(table.raw)
  if init_params[:rules].kind_of? Array
    init_params[:rules].map! { |r| expand_path(r) }
  else
    init_params[:rules] = [expand_path(init_params[:rules])]
  end
  browser_opts = [
    File.expand_path('browser_opts.yml', init_params[:rules].first),
    File.expand_path('../browser_opts.yml', init_params[:rules].first)
  ]
  browser_opts.any? do |file|
    if File.exists? file
      init_params.merge! YAML.load_file(file)
    end
  end
  if conf[:browser]
    init_params[:browser_type] ||= conf[:browser].to_sym
  end
  if conf[:selenium_url]
    init_params[:selenium_url] ||= conf[:selenium_url]
  end
  if env.client_proxy
    init_params[:http_proxy] ||= env.client_proxy
  end
  init_params[:logger] = logger
  browser = Web4Cucumber.new(**init_params)
  cache_browser(browser)
  teardown_add { @result = browser.finalize }
end

Given /^I open registry console in a browser$/ do
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR + "/base/"
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR
  step "default registry-console route is stored in the :reg_console_url clipboard"
  step "I have a browser with:", table(%{
    | rules        | #{base_rules}                     |
    | rules        | lib/rules/web/registry_console/   |
    | base_url     | https://<%= cb.reg_console_url %> |
    | snippets_dir | #{snippets_dir}                   |
                                     })
  @result = browser.run_action(:goto_registry_console)
  step 'I perform login to registry console in the browser'
end

When /^I perform login to registry console in the browser$/ do
  @result = if user.password?
    browser.run_action(:login_reg_console,
                       username: user.name,
                       password: user.password)
  else
    browser.run_action(:login_token_reg_console,
                       token: user.cached_tokens.first)
  end
end

# @precondition a `browser` object
# get element html or attribute value
# Provide element selector in the step table using key/value pairs, e.g.
# And I get the "disabled" attribute of the "button" web element with:
#   | type | submit |
When /^I get the (?:"([^"]*)" attribute|content) of the "([^"]*)" web element:$/ do |attribute, element_type, table|
  transform binding, :attribute, :element_type, :table
  selector = opts_array_to_hash(table.raw)
  #Collections.map_hash!(selector) do |key, value|
  #  [ key, YAML.load(value) ]
  #end

  found_elements = browser.get_visible_elements(type:     element_type,
                                                selector: selector)

  if found_elements.empty?
    raise "can not find this #{element_type} element with #{selector}"
  else
    if attribute
      value = found_elements.last.attribute_value(attribute)
    else
      value = found_elements.last.html
    end
    @result = {
      response: value,
      success: true,
      exitstatus: -1,
      instruction: "get the #{attribute ? attribute + ' attibute' : ' content'} of the #{element_type} element with selector: #{selector}"
    }
  end
end

# @precondition a `browser` object
When /^I get the html of the web page$/ do
  @result = {
    response: browser.page_html,
    success: true,
    instruction: "read the HTML of the currently opened web page",
    exitstatus: -1
  }
end

# @precondition a `browser` object
# useful for web common "click" action
When /^I click the following "([^"]*)" element:$/ do |element_type, table|
  transform binding, :element_type, :table
  selector = opts_array_to_hash(table.raw)
  @result = browser.handle_element({type: element_type, selector: selector, op: "click"})
end

# @precondition a `browser` object
# return the text of html body
When /^I get the visible text on web html page$/ do
  @result = {
    response: browser.text,
    success: true,
    instruction: "read the visible body TEXT of the currently opened web page",
    exitstatus: -1
  }
end

# repeat doing web action until success,useful for waiting resource to become visible and available on web
Given /^I wait(?: (\d+) seconds)? for the :(.+?) web( console)? action to succeed with:$/ do |time, web_action, console, table|
  transform binding, :time, :web_action, :console, :table
  time = time ? time.to_i : 15 * 60
  if console
    step_string = "I perform the :#{web_action} web console action with:"
  else
    step_string = "I perform the :#{web_action} web action with:"
  end
  success = wait_for(time) {
    step step_string, table
    break true if @result[:success]
  }
  @result[:success] = success
  unless @result[:success]
    raise "can not wait the :#{web_action} web action to succeed"
  end
end

# @precondition a `browser` object
Given /^I wait(?: (\d+) seconds)? for the title of the web browser to match "(.+)"$/ do |time, pattern|
  transform binding, :time, :pattern
  time = time ? time.to_i : 10
  reg = Regexp.new(pattern)
  success = wait_for(time) {
    reg =~ browser.title
  }
  unless success
    raise "browser title #{browser.title} did not match #{pattern} within timeout"
  end
end


# @notes used for swithing browser window,e.g. do some action in pop-up window
# @window_spec is something like,":url=>console\.html"(need escape here,part of url),":title=>some info"(part of title)
When /^I perform the :(.*?) web( console)? action in "([^"]+)" window with:$/ do |action, console, window_spec, table|
  transform binding, :action, :console, :window_spec, :table
  window_selector = opts_array_to_hash([window_spec.split("=>")])
  window_selector.each{ |key,value| window_selector[key] = Regexp.new(value) }
  if console
    cache_browser(user.webconsole_executor)
    webexecutor = user.webconsole_executor
  else
    webexecutor = browser
  end

  if webexecutor.browser.window(window_selector).exists?
    webexecutor.browser.window(window_selector).use do
      @result = webexecutor.run_action(action.to_sym, opts_array_to_hash(table.raw))
      @result[:url] = webexecutor.browser.window(window_selector).url
      @result[:text] = webexecutor.browser.text
    end
  else
    for win in webexecutor.browser.windows
      logger.warn("window title: #{win.title}, window url: #{win.url}")
    end
    raise "can not switch to the specific window"
  end
end

# perhaps we can get rid of this step since it's so short??
Given /^I open metrics console in the browser$/ do
  metrics_url = env.metrics_console_url + "/metrics"
  step %Q/I access the "#{metrics_url}" url in the web browser/
end

# close out current browser to conserve system memory during test
Given /^I close the current browser$/ do
  browser.finalize
end

Given /^I check all relatedObjects of clusteroperator "(.*?)" are shown/ do |clusteroperator_name|
  transform binding, :clusteroperator_name
  ensure_admin_tagged
  #get relatedObjects of clusteroperator
  relatedObjectsArray = cluster_operator(clusteroperator_name).related_objects
  relatedObjectsArray.each do |related_object|
    if !related_object.key?('name') or related_object['name'] == ""
      next
    end

    if !related_object.key?('group') or related_object['group'] == ""
      related_object_group = '-'
    else
      related_object_group = related_object['group']
    end

    if !related_object.key?('namespace') or related_object['namespace'] == ""
      related_object_ns = '-'
    else
      related_object_ns = related_object['namespace']
    end
    step "I perform the :check_co_related_objs web action with:", table(%{
      | name      | #{related_object['name']}     |
      | resource  | #{related_object['resource']} |
      | group     | #{related_object_group}       |
      | namespace | #{related_object_ns}          |
    })
    step %Q/the step should succeed/
  end
end
