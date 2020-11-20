# helper step for logging and metrics scenarios
require 'oga'
require 'parseconfig'
require 'stringio'
require 'prometheus_metrics_data'

# helper step that does the following:
# 1. figure out project and route information
Given /^I login to kibana logging web console$/ do
  cb.logging_console_url = route('kibana', service('kibana',project('openshift-logging', switch: false))).dns(by: admin)
  base_rules = BushSlicer::WebConsoleExecutor::RULES_DIR + "/base/"
  snippets_dir = BushSlicer::WebConsoleExecutor::SNIPPETS_DIR
  version = env.webconsole_executor.get_master_version(user, via_rest: true)
  step %Q/I have a browser with:/, table(%{
    | rules        | lib/rules/web/admin_console/#{version}/  |
    | rules        | #{base_rules}                            |
    | rules        | lib/rules/web/admin_console/base/        |
    | snippets_dir | #{snippets_dir}                          |
    | base_url     | <%= cb.logging_console_url %>            |
    })
  step %Q/I perform the :kibana_login web action with:/, table(%{
    | username   | <%= user.name %>                      |
    | password   | <%= user.password %>                  |
    | kibana_url | https://<%= cb.logging_console_url %> |
    | idp        | <%= env.idp %>                        |
    })
  # change the base url so we don't need to specifiy kibana url every time afterward in the rule file
  browser.base_url = cb.logging_console_url
end

When /^I wait(?: (\d+) seconds)? for the #{QUOTED} index to appear in the ES pod(?: with labels #{QUOTED})?$/ do |seconds, index_name, pod_labels|
  if pod_labels
    labels = pod_labels
  else
    labels = "es-node-master=true"
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | #{labels} |
  })

  seconds = Integer(seconds) unless seconds.nil?
  seconds ||= 10 * 60
  index_data = nil
  success = wait_for(seconds) {
    step %Q/I get the "#{index_name}" logging index information from a pod with labels "#{labels}"/
    res = cb.index_data
    if res
      index_data = res
      # exit only health is not 'red' and index is 'open' and the docs.count > 0
      # XXX note, to be more correct, we should check that the index is not red
      # for an extended persiod.  The tricky part is how to define extended period????
      # for now, just consider it not red to be good
      #https://www.elastic.co/guide/en/elasticsearch/reference/5.6/cluster-health.html
      res['health'] != 'red' and res['status'] == 'open' and res['docs.count'].to_i > 0
    end
  }
  raise "Index '#{index_name}' failed to appear in #{seconds} seconds" unless success
end

# must execute in the es-xxx pod
# @return stored data into cb.index_data
When /^I get the #{QUOTED} logging index information(?: from a pod with labels #{QUOTED})?$/ do | index_name, pod_labels |
  if pod_labels
    labels = pod_labels
  else
    labels = "es-node-master=true"
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | #{labels} |
  })
  step %Q/I perform the HTTP request on the ES pod with labels "#{labels}":/, table(%{
    | relative_url | _cat/indices?format=JSON |
    | op           | GET                      |
  })
  res_indices = @result[:parsed].find_all{|e| e['index'].start_with? index_name}
  if res_indices.length() > 0
    cb.index_data=res_indices.sort_by{|e| e['index']}.reverse()[0]
    true
  else
    cb.index_data=nil
    false
  end 
end

# just do the query, check result outside of the step.
# @relative_url: relative url of the query
# @op: operation we want to perform (GET, POST, DELETE, and etc)
Given /^I perform the HTTP request on the ES pod(?: with labels #{QUOTED})?:$/ do |pod_labels, table|
  if pod_labels
    labels = pod_labels
  else
    labels = "es-node-master=true"
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | #{labels} |
  })
  opts = opts_array_to_hash(table.raw)
  # sanity check
  required_params = [:op, :relative_url]
  required_params.each do |param|
    raise "Missing parameter '#{param}'" unless opts[param]
  end
  # if user specify token, curl command should use it instead of usering the system cert
  if opts[:token]
    query_url = service('elasticsearch').url
    query_opts = "-H \"Authorization: Bearer #{opts[:token]}\" -H \"Content-Type: application/json\""
    query_cmd = "curl -sk #{query_opts} 'https://#{query_url}/#{opts[:relative_url]}' -X #{opts[:op]}"
  else
    query_cmd = "es_util '--query=#{opts[:relative_url]}' -X #{opts[:op]}"
  end
  @result = pod.exec("bash", "-c", query_cmd, as: admin, container: 'elasticsearch')
  if @result[:success]
    @result[:parsed] = YAML.load(@result[:response])
    # curl returns 0 even with a http code of 403, we force it to match.
    if @result[:parsed].is_a? Hash and @result[:parsed].has_key? 'status'
      @result[:exitstatus] = @result[:parsed]['status']
    end
  else
    raise "HTTP operation failed with error, #{@result[:response]}"
  end
end

Given /^I check the #{QUOTED} prometheus rule in the #{QUOTED} project on the prometheus server$/ do | prometheus_rule_name, project_name |
  step %Q/I run the :exec client command with:/, table(%{
    | n                | openshift-monitoring                                                                          |
    | container        | prometheus                                                                                    |
    | pod              | prometheus-k8s-0                                                                              |
    | oc_opts_end      |                                                                                               |
    | exec_command     | cat                                                                                           |
    | exec_command_arg | /etc/prometheus/rules/prometheus-k8s-rulefiles-0/#{project_name}-#{prometheus_rule_name}.yaml |
  })
  step %Q/the step should succeed/
end
