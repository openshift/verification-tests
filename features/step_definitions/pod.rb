Given /^a pod becomes ready with labels:$/ do |table|
  labels = table.raw.flatten # dimentions irrelevant
  pod_timeout = 15 * 60

  @result = BushSlicer::Pod.wait_for_labeled(*labels, user: user, project: project, seconds: pod_timeout) { |p,h| p.ready?(cached: true)[:success] }

  if @result[:matching].empty?
    # logger.info("Pod list:\n#{@result[:response]}")
    # logger.error("Waiting for labeled pods futile: #{labels.join(",")}")
    logger.error(@result[:response])
    raise "See log, timeout waiting for ready pods with " \
      "labels: #{labels.join(',')}"
  end

  cache_pods(*@result[:matching])
end

Given /^the pod(?: named "(.+)")? becomes ready$/ do |name|
  ready_timeout = 15 * 60
  @result = pod(name).wait_till_ready(user, ready_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod did not become ready"
  end
end

Given /^the pod(?: named "(.+)")? is ready$/ do |name|
  @result = pod(name).ready?(user: user, cached: false)

  unless @result[:success]
    raise "#{pod.name} pod is not ready"
  end
end

Given /^the pod(?: named "(.+)")? becomes terminating$/ do |name|
  ready_timeout = 60
  @result = pod(name).wait_till_terminating(user, ready_timeout)

  unless @result[:success]
    raise "#{pod.name} pod did not become terminating"
  end
end


Given /^the pod(?: named "(.+)")? becomes present$/ do |name|
  present_timeout = 5 * 60
  @result = pod(name).wait_to_appear(user, present_timeout)

  unless @result[:success]
    logger.error(@result[:response])
    step %Q{I get project events}
    raise "#{pod.name} pod was never present"
  end
end

Given /^a pod is present with labels:$/ do |table|
  labels = table.raw.flatten
  pod_timeout = 5 * 60

  pods = project.pods(by:user)

  @result = BushSlicer::Pod.wait_for_labeled(*labels, user: user, project: project, seconds: pod_timeout)
  if @result[:matching].empty?
    raise "See log, waiting for labeled pods futile: #{labels.join(',')}"
  end

  cache_pods(*@result[:matching])
end

Given /^I store in the#{OPT_SYM} clipboard the pods labeled:$/ do |cbn, labels|
  cbn ||= :pods
  cb[cbn] = BushSlicer::Pod.get_labeled(*labels.raw.flatten,
                                       project: project,
                                       user: user)
end

Given /^the pod(?: named "(.+)")? status becomes :([^\s]*?)(?: within #{NUMBER} seconds)?$/ do |name, status, timeout|
  timeout = timeout ? Integer(timeout) : 15 * 60
  @result = pod(name).wait_till_status(status.to_sym, user, timeout)

  unless @result[:success]
    # logger.error(@result[:response])
    pod.describe(user, quiet: false)
    raise "#{pod.name} pod did not become #{status}"
  end
end

Given /^status becomes :([^\s]*?) of( exactly)? ([0-9]+) pods? labeled:$/ do |status, exact_count, count, labels|
  timeout = 15 * 60
  labels = labels.raw.flatten

  @result = BushSlicer::Pod.wait_for_labeled(*labels, count: count.to_i,
              user: user, project: project, seconds: timeout) { |p, p_hash|
    p.status?(status: status.to_sym, user: user, cached: true, quiet: true)
  }

  cache_pods(*@result[:items], *@result[:matching])

  count_good = !exact_count || @result[:matching].size == count.to_i

  unless @result[:success] && count_good
    raise "desired num of pods did not become #{status}"
  end
end

# for a rc that has multiple pods, oc describe currently doesn't support json/yaml output format, so do 'oc get pod' to get the status of each pod
Given /^all the pods in the project reach a successful state$/ do
  pods = project.pods(by:user)
  logger.info("Number of pods: #{pods.count}")
  pods.each do | pod |
    cache_pods(pod)
    res = pod.wait_till_status(BushSlicer::Pod::SUCCESS_STATUSES, user, 15*60)

    unless res[:success]
      raise "pod #{self.pod.name} did not reach expected status"
    end
  end
end

# use this with care and it just all of the pods in the project, better to filter out the pods with labels if possible
Given /^all pods in the project are ready$/ do
  pods = project.pods(by:user)
  ready_timeout = 15 * 60
  logger.info("Number of pods: #{pods.count}")
  pods.each do |pod|
    cache_pods(pod)
    @result = pod.wait_till_ready(user, ready_timeout)
    unless @result[:success]
      raise "pod #{pod.name} did not become ready within allowed time"
    end
  end
end

Given /^#{NUMBER} pods? becomes? ready with labels:$/ do |count, table|
  labels = table.raw.flatten # dimentions irrelevant
  pod_timeout = 10 * 60
  ready_timeout = 15 * 60
  num = Integer(count)

  # TODO: make waiting a single step like for PVs and PVCs
  @result = BushSlicer::Pod.wait_for_labeled(*labels, count: num,
                       user: user, project: project, seconds: pod_timeout)

  if !@result[:success] || @result[:matching].size < num
    logger.error("Wanted #{num} but only got '#{@result[:matching].size}' pods labeled: #{labels.join(",")}")
    raise "See log, waiting for labeled pods futile: #{labels.join(',')}"
  end

  cache_pods(*@result[:matching])

  # keep last waiting @result as the @result for knowing how pod failed
  @result[:matching].each do |pod|
    @result = pod.wait_till_status(BushSlicer::Pod::SUCCESS_STATUSES, user, ready_timeout)

    unless @result[:success]
      pod.describe(user, quiet: false)
      raise "pod #{pod.name} did not reach expected status"
    end
  end
end

# useful for waiting the deployment pod to die and complete
# Called without the 'regardless...' parameter ir checks that pod reaches a
#   ready status, then somehow dies. With the parameter it just makes sure
#   pod os not there regardless of its current status.
Given /^I wait for the pod(?: named #{QUOTED})? to die( regardless of current status)?$/ do |name, ignore_status|
  ready_timeout = 15 * 60
  @result = pod(name).wait_till_ready(user, ready_timeout) unless ignore_status
  if ignore_status || @result[:success]
    @result = pod(name).wait_till_not_ready(user, ready_timeout)
  end
  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod did not die"
  end
end

Given /^(admin executes|all) existing pods die with labels:$/ do |by,table|
  _user = by.split.first == "admin" ? admin : user
  labels = table.raw.flatten # dimensions irrelevant
  timeout = 10 * 60
  start_time = monotonic_seconds

  current_pods = BushSlicer::Pod.get_matching(user: _user, project: project,
                                             get_opts: {l: selector_to_label_arr(*labels)})

  current_pods.each do |pod|
    @result =
        pod.wait_till_status(BushSlicer::Pod::TERMINAL_STATUSES, _user,
                             timeout - monotonic_seconds + start_time)
    unless @result[:success]
      raise "pod #{pod.name} did not die within allowed time"
    end
  end
end

Given /^all existing pods are ready with labels:$/ do |table|
  labels = table.raw.flatten # dimensions irrelevant
  timeout = 15 * 60
  start_time = monotonic_seconds

  current_pods = BushSlicer::Pod.get_matching(user: user, project: project,
                                             get_opts: {l: selector_to_label_arr(*labels)})

  current_pods.each do |pod|
    cache_pods(pod)
    @result = pod.wait_till_ready(user, timeout - monotonic_seconds + start_time)
    unless @result[:success]
      raise "pod #{pod.name} did not become ready within allowed time"
    end
  end
end

# args can be a table where each cell is a command or an argument, or a
#   multiline string where each line is a command or an argument
When /^(I execute|admin executes) on the#{OPT_QUOTED} pod(?: #{QUOTED} container)?:$/ do |by, pod_name, container, raw_args|
  _user = by.split.first == "admin" ? admin : user
  if raw_args.respond_to? :raw
    # this is table, we don't mind dimentions used by user
    args = raw_args.raw.flatten
  else
    # multi-line string; useful when piping is needed
    args = raw_args.split("\n").map(&:strip)
  end

  @result = pod(pod_name).exec(*args, as: _user, container: container)
end

# wrapper around  oc logs, keep executing the command until we have an non-empty response
# There are few occassion that the 'oc logs' cmd returned empty response
#   this step should address those situations
Given /^I collect the deployment log for pod "(.+)" until it disappears$/ do |pod_name|
  opts = {resource_name: pod_name}
  res_cache = {}
  res = {}
  seconds = 15 * 60   # just put a timeout so we don't hang there indefintely
  success = wait_for(seconds) {
    res = user.cli_exec(:logs, **opts)
    if res[:response].include? 'not found'
      # the deploy pod has disappeared which mean we are done waiting.
      true
    else #
      res_cache = res
      false
    end
  }
  res_cache[:success] = success
  @result  = res_cache
end

Given /^I collect the deployment log for pod "(.+)" until it becomes :([^\s]*?)$/ do |name, status|
  opts = {resource_name: name}
  timeout = 15 * 60   # just put a timeout so we don't hang there indefintely
  podstatus = pod(name).wait_till_status(status.to_sym, user, timeout)
  unless podstatus[:success]
    logger.error(podstatus[:response])
    raise "pod #{name} didn't become #{status}"
  end

  @result = user.cli_exec(:logs, **opts)
end

# pod_info is the user pod, for example.... deployment-example
# the step will do 'docker ps | grep deployment-example' to filter out a target
# TODO: cri-o is not implemented yet
Given /^the system container id for the#{OPT_QUOTED} pod is stored in the#{OPT_SYM} clipboard$/ do | pod_name, cb_name |
  cb_name ||= :system_pod_container_id
  system_pod_container_id_regexp=/^(.*)\s+.*(ose|origin)-pod:.+\s/
  pod_name = pod(pod_name).name
  res = host.exec("docker ps | grep #{pod_name}")
  system_pod_container_id = nil
  if res[:success]
    res[:response].split("\n").each do | line |
      system_pod_container_id = system_pod_container_id_regexp.match(line)
      break unless system_pod_container_id.nil?
    end
  else
    raise "Can't find matching docker information for #{pod_name}"
  end
  raise "Can't find containter id for system pod" if system_pod_container_id.nil?
  cb[cb_name] = system_pod_container_id[1].strip
end

Given /^I check containers cpu request for pod named #{QUOTED} under limit:$/ do |pod_name, table|
  container_cpu_hash = table.rows_hash
  step %Q/I run the :get client command with:/, table(%{
    | resource      | pods                                                                           |
    | resource_name | #{pod_name}                                                                    |
    | o             | go-template={{range.spec.containers}}{{.resources.requests.cpu}}{{"#"}}{{end}} |
  })
  cpus=@result[:stdout].split(/#/).map{|n| n.delete('m').to_i}
  step %Q/I run the :get client command with:/, table(%{
    | resource      | pods                                                         |
    | resource_name | #{pod_name}                                                  |
    | o             | go-template={{range.spec.containers}}{{.name}}{{"#"}}{{end}} |
  })
  containers=@result[:stdout].split(/#/)
  for i in 0..containers.length-1
    underlimit=container_cpu_hash.include?(containers[i])?cpus[i]<container_cpu_hash[containers[i]].to_i : cpus[i]<container_cpu_hash["default_limit"].to_i
    raise "#{containers[i]} cpu limit #{cpus[i]} is over" unless underlimit    
  end    
end
