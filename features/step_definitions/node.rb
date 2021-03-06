# nodes related steps

# IMPORTANT: Creating new [Node] objects is discouraged. Access nodes
#   through `env.nodes` when possible. This is to ensure we use the same
#   objects throughout test execution keeping correct status like config file
#   modification state.

Given /^fips is (enabled|disabled)$/ do |status|
  transform binding, :status
  ensure_admin_tagged
  step %Q/I run the :get admin command with:/, table(%{
    | resource | machineconfigs |
  })
  if status == 'enabled'
    step %Q/the output should contain:/, table(%{
      | 99-master-fips |
      | 99-worker-fips |
    })
  else
    step %Q/the output should not contain:/, table(%{
      | 99-master-fips |
      | 99-worker-fips |
    })
  end
end

# select a random node from a cluster.
Given /^I select a random node's host$/ do
  ensure_admin_tagged
  nodes = env.nodes.select { |n| n.schedulable? }
  cache_resources *nodes.shuffle
  @host = node.host
end

Given /^I store the( schedulable| ready and schedulable)? (node|master|worker)s in the#{OPT_SYM} clipboard(?: excluding #{QUOTED})?$/ do |state, role, cbname, exclude|
  transform binding, :state, :role, :cbname, :exclude
  ensure_admin_tagged
  cbname = 'nodes' unless cbname

  if exclude
    nodes = env.nodes.select { |n| n.name != exclude }
  else
    nodes = env.nodes.dup
  end

  if !state
    cb[cbname] = nodes
  elsif state.strip == "schedulable"
    cb[cbname] = nodes.select { |n| n.schedulable? }
  else
    cb[cbname] = nodes.select { |n| n.ready? && n.schedulable? }
  end

  if role == "worker"
    cb[cbname] = cb[cbname].select { |n| n.is_worker? }
  elsif role == "master"
    cb[cbname] = cb[cbname].select { |n| n.is_master? }
  end

  cache_resources *cb[cbname].shuffle
end

Given /^(I|admin) stores? in the#{OPT_SYM} clipboard the nodes backing pods(?: in project #{QUOTED})? labeled:$/ do |who, cbname, project, labels|
  transform binding, :who, :cbname, :project, :labels
  if who == "admin"
    ensure_admin_tagged
    _user = admin
  else
    _user = user
  end

  pods = BushSlicer::Pod.get_labeled(*labels.raw.flatten,
                                       project: project(project),
                                       user: _user)

  node_names = pods.map(&:node_name)

  cbname ||= "nodes"
  cb[cbname] = node_names.map { |n| node(n) }
end

Given /^environment has( at least| at most) (\d+)( schedulable)? nodes?$/ do |cmp, num, schedulable|
  transform binding, :cmp, :num, :schedulable
  ensure_admin_tagged
  nodes = env.nodes.select { |n| !schedulable || n.schedulable?}
  cache_resources *nodes.shuffle

  case cmp
  when /at least/
    raise "nodes are #{nodes.size}" unless nodes.size >= num.to_i
  when /at most/
    raise "nodes are #{nodes.size}" unless nodes.size <= num.to_i
  else
    raise "nodes are #{nodes.size}" unless nodes.size == num.to_i
  end
end

# @host from World will be used.
Given /^I run( background)? commands on the host:$/ do |bg, table|
  transform binding, :bg, :table
  ensure_admin_tagged

  raise "You must set a host prior to running this step" unless host
  @result = host.exec(*table.raw.flatten, background: !!bg)
end

Given /^I run commands on the host after scenario:$/ do |table|
  transform binding, :table
  _host = @host
  _command = *table.raw.flatten
  logger.info "Will run the command #{_command} after scenario on #{_host.hostname}"
  teardown_add {
    @result = _host.exec_admin(_command)
    unless @result[:success]
      raise "could not execute comands #{_command} on #{_host.hostname}"
    end
  }
end

Given /^I run( background)? commands on the hosts in the#{OPT_SYM} clipboard:$/ do |bg, cbname, table|
  transform binding, :bg, :cbname, :table
  ensure_admin_tagged
  cbname ||= "hosts"

  unless Array === cb[cbname] && cb[cbname].size > 0 &&
      cb[cbname].all? {|e| BushSlicer::Host === e}
    raise "You must set a clipboard prior to running this step"
  end

  results = cb[cbname].map { |h| h.exec(*table.raw.flatten, background: !!bg) }
  @result = results.find {|r| !r[:success] }
  @result ||= results[0]
  @result[:channel_object] = results.map { |r| r[:channel_object] }
  @result[:response] = results.map { |r| r[:response] }
  @result[:exitstatus] = results.map { |r| r[:exitstatus] }
end

Given /^I run( background)? commands on the nodes in the#{OPT_SYM} clipboard:$/ do |bg, cbname, table|
  transform binding, :bg, :cbname, :table
  ensure_admin_tagged
  cbname ||= "nodes"

  tmpcb = rand_str(5, "dns")
  cb[tmpcb] = cb[cbname].map(&:host)

  step "I run#{bg} commands on the hosts in the :#{tmpcb} clipboard:", table

  cb[tmpcb] = nil
end

# use a specific node in cluster
Given /^I use the #{QUOTED} node$/ do | host |
  transform binding, :host
  @host = node(host).host
end

# restore particular file after scenario; if missing, then removes it
Given /^the #{QUOTED} file is restored on host after scenario$/ do |path|
  transform binding, :path
  _host = @host

  # check path sanity
  if ["'", "\n", "\\"].find {|c| path.include? c}
    raise "please specify path with sane characters"
  end

  # tar the file on host so we can restore with permissions later
  @result = _host.exec_admin("find '#{path}' -maxdepth 0 -type f")
  if @result[:success]
    if @result[:response].empty?
      raise "target path not a file"
    else
      # file exist
      @result = _host.exec_admin("tar --selinux --acls --xattrs -cvPf '#{path}.tar' '#{path}'")
      raise "could not archive target file" unless @result[:success]
      _restore_command = "tar xvPf '#{path}.tar' && rm -f '#{path}.tar'"
    end
  else
    # file does not exist
    _restore_command = "rm -f '#{path}'"
  end


  teardown_add {
    @result = _host.exec_admin(_restore_command)
    unless @result[:success]
      raise "could not restore #{path} on #{_host.hostname}"
    end
  }
end

# if clipboard is not specified step will try :hosts and :nodes
# the content of clipboard can either be Array<Host> or Array<Node>
Given /^the #{QUOTED} file is restored on all hosts in the#{OPT_QUOTED} clipboard after scenario$/ do |path, cb_name|
  transform binding, :path, :cb_name
  unless cb_name
    if cb.hosts
      cb_name = :hosts
    elsif cb.nodes
      cb_name = :nodes
    else
      raise "couldn't find the clipboard with the nodes"
    end
  end

  orig_host = @host
  cb[cb_name].each { |h|
    @host = BushSlicer::Host === h ? h : h.host
    step %{the "#{path}" file is restored on host after scenario}
  }
  @host = orig_host
end

# restore particular file after scenario
Given /^the #{QUOTED} path is( recursively)? removed on the host after scenario$/ do |path, recurse|
  transform binding, :path, :recurse
  _host = @host
  path = _host.absolutize(path)

  # check path sanity
  if ["'", "\n", "\\"].find {|c| path.include? c}
    raise "please specify path with sane characters"
  end
  # lame check for not removing root directories
  unless path =~ %r{^/\.?[^/.]+.*/\.?[^/.]+.*}
    raise "path must be at least 2 levels deep"
  end

  teardown_add {
    success = _host.delete(path, r: !!recurse)
    raise "can't remove #{path} on #{_host.hostname}" unless success
  }
end

Given /^the node service is restarted on the host( after scenario)?$/ do |after|
  transform binding, :after
  ensure_destructive_tagged
  _node = env.nodes.find { |n| n.host.hostname == @host.hostname }

  unless _node
    raise "cannot find node for host #{@host.hostname}"
  end

  _op = proc {
    _node.service.restart(raise: true)
  }

  if after
    logger.info "Node service will be restarted after scenario on #{_node.name}"
    teardown_add _op
  else
    _op.call
  end
end

# the step does not register clean-ups because these usually are properly
#   ordered in scenario itself, we don't want automatic extra restarts
Given /^the#{OPT_QUOTED} node service is stopped$/ do |node_name|
  transform binding, :node_name
  ensure_destructive_tagged
  node(node_name).service.stop(raise: true)
end

Given /^label #{QUOTED} is added to the#{OPT_QUOTED} node$/ do |label, node_name|
  transform binding, :label, :node_name
  ensure_admin_tagged

  _admin = admin
  _node = node(node_name)

  _opts = {resource: :node, name: _node.name, overwrite: true}
  label_now = {key_val: label}
  label_key = label.sub(/^(.*?)=.*$/, "\\1")
  label_clean = {key_val:  label_key + "-"}

  if _node.labels.has_key?(label_key)
    step %Q/the "#{_node.name}" node labels are restored after scenario/
  else
    teardown_add {
      @result = _admin.cli_exec(:label, **_opts, **label_clean)
      unless @result[:success]
        raise "cannot remove label #{label} from node #{_node.name}"
      end
    }
  end

  @result = _admin.cli_exec(:label, **_opts, **label_now)
  raise "cannot add label to node" unless @result[:success]

end

Given /^the#{OPT_QUOTED} node service is verified$/ do |node_name|
  transform binding, :node_name
  ensure_admin_tagged

  _node = node(node_name)
  _host = _node.host

  # to reduce test execution time we stop creating a pod to verify node
  # if this turns out to be a problem, before reenable, make sure we
  # use a project without node selector. Otherwise things break on 3.9+
  # see OPENSHIFTQ-12320
  #
  #_pod_name = "hostname-pod-" + rand_str(5, :dns)
  #_pod_obj = <<-eof
  #  {
  #    "apiVersion":"v1",
  #    "kind": "Pod",
  #    "metadata": {
  #      "name": "#{_pod_name}",
  #      "labels": {
  #        "puspose": "testing-node-validity",
  #        "name": "hostname-pod"
  #      }
  #    },
  #    "spec": {
  #      "containers": [{
  #        "name": "hostname-pod",
  #        "image": "quay.io/openshifttest/hello-openshift@sha256:424e57db1f2e8e8ac9087d2f5e8faea6d73811f0b6f96301bc94293680897073",
  #        "ports": [{
  #          "containerPort": 8080,
  #          "protocol": "TCP"
  #        }]
  #      }],
  #      "nodeName" : "#{_node.name}"
  #    }
  #  }
  #eof

  svc_verify = proc {
    # node service running
    @result = _host.exec_admin('systemctl status kubelet')
    unless @result[:success] || @result[:response].include?("active (running)")
      raise "kubelet service not running, see log"
    end
    # pod can be scheduled on node
    #step 'I have a project'
    #@result = admin.cli_exec(:create, f: "-", _stdin: _pod_obj, n: project.name)
    #raise "cannot create verification pod, see log" unless @result[:success]
    #step %Q{the pod named "#{_pod_name}" becomes ready}
    #unless _node.name == pod(_pod_name).node_name(user: admin, quiet: true)
    #  raise "verification node not running on correct node"
    #end
    ## thought it would be good enough check but we can switch to creating
    #    a route and then accessing it in case this proves not stable enough
    #@result = _host.exec("curl -sS #{pod.ip(user: user)}:8080")
    #unless @result[:success] || @result[:response].include?("Hello OpenShift!")
    #  raise "verification pod doesn't serve properly, see log"
    #end
    #@result = pod(_pod_name).delete(by: user, grace_period: 0)
    #raise "can't delete verification pod" unless @result[:success]
  }

  svc_verify.call
  teardown_add svc_verify
end

Given /^the host is rebooted and I wait it(?: up to (\d+) seconds)? to become available$/ do |timeout|
  transform binding, :timeout
  timeout = timeout ? Integer(timeout) : 300
  @host.reboot_checked(timeout: timeout)
end

Given /^the#{OPT_QUOTED} node labels are restored after scenario$/ do |node_name|
  transform binding, :node_name
  ensure_destructive_tagged
  _node = node(node_name)
  _node_labels = _node.labels
  _admin = admin

  logger.info "Node labels are stored in clipboard"

  teardown_add {
    labels = _node_labels.map {|k,v| [:key_val, k + "=" + v] }
    opts = [ [:resource, 'node'], [:name, _node.name], [:overwrite, true], *labels ]
    _admin.cli_exec(:label, opts)
  }
end

Given /^config of all( schedulable)? nodes is merged with the following hash:$/ do |schedulable, yaml_string|
  transform binding, :schedulable, :yaml_string
  ensure_destructive_tagged

  nodes = env.nodes.select { |n| !schedulable || n.schedulable? }
  services = nodes.map(&:service)

  services.each { |service|
    service_config = service.config
    service_config.merge! yaml_string

    teardown_add {
      service_config.restore()
    }
  }
end

Given /^node#{OPT_QUOTED} config is merged with the following hash:$/ do |node_name, yaml_string|
  transform binding, :node_name, :yaml_string
  ensure_destructive_tagged

  service_config = node(node_name).service.config
  service_config.merge! yaml_string

  teardown_add {
    service_config.restore()
  }
end

Given /^all nodes config is restored$/ do
  ensure_destructive_tagged
  BushSlicer::ResultHash.aggregate_results(
    *env.nodes.map(&:service).each { |s| s.config.restore() }
  )
end


Given /^node#{OPT_QUOTED} config is restored from backup$/ do |node_name|
  transform binding, :node_name
  ensure_destructive_tagged
  @result = node(node_name).service.config.restore()
end

Given /^the value with path #{QUOTED} in node config is stored into the#{OPT_SYM} clipboard$/ do |path, cb_name|
  transform binding, :path, :cb_name
  ensure_admin_tagged
  config_hash = node.service.config.as_hash()
  cb_name ||= "config_value"
  cb[cb_name] = eval "config_hash#{path}"
end

Given /^the node service is restarted on all( schedulable)? nodes$/ do |schedulable|
  transform binding, :schedulable
  ensure_destructive_tagged
  nodes = env.nodes.select { |n| !schedulable || n.schedulable? }
  services = nodes.map(&:service)

  services.each { |service|
    service.restart(raise: true)
  }
end

Given /^the#{OPT_QUOTED} node service is restarted$/ do |node_name|
  transform binding, :node_name
  ensure_destructive_tagged
  node(node_name).service.restart(raise: true)
end

Given /^I try to restart the node service on all( schedulable)? nodes$/ do |schedulable|
  transform binding, :schedulable
  ensure_destructive_tagged
  results = []
  nodes = env.nodes.select { |n| !schedulable || n.schedulable? }
  services = nodes.map(&:service)

  services.each { |service|
    results.push(@result = service.restart)
  }

  @result = BushSlicer::ResultHash.aggregate_results(results)
end

Given /^I try to restart the node service on node#{OPT_QUOTED}$/ do |node_name|
  transform binding, :node_name
  ensure_destructive_tagged
  @result = node(node_name).service.restart
end

Given /^I have (?:(at least ))?(\d+) nodes?$/ do |quantifier, nodes|
  transform binding, :quantifier, :nodes
  num_of_nodes = nodes.to_i
  nodes_found = env.nodes.count
  @result = {}
  if quantifier
    @result[:success] = nodes_found >= num_of_nodes
  else
    @result[:success] = nodes_found == num_of_nodes
  end
  raise "number of nodes '#{nodes_found}' in the setup does not meet the criteria of #{quantifier}#{nodes} nodes" unless @result[:success]
end

# use oc rsync to copy files from node to a pod
# required table params are src_dir and dst_dir
Given /^I rsync files from node named #{QUOTED} to pod named #{QUOTED} using parameters:$/ do | node_name, pod_name, table |
  transform binding, :node_name, :pod_name, :table
  ensure_admin_tagged
  opts = opts_array_to_hash(table.raw)
  raise "Not all requried parameters given, expected #{opts.keys}" if opts.keys.sort != [:dst_dir, :src_dir]
  step %Q/I run commands on the host:/, table(%{
    | oc rsync "#{opts[:src_dir]}" "#{opts[:dst_dir]}" --namespace "#{project.name}" |
  })
  step %Q/the step should succeed/
end

Given /^the taints of the nodes in the#{OPT_SYM} clipboard are restored after scenario$/ do |nodecb|
  transform binding, :nodecb
  ensure_destructive_tagged

  nodecb ||= :nodes
  _admin = admin
  _nodes = cb[nodecb].dup
  _original_taints = _nodes.map { |n| [n,n.taints] }.to_h

  teardown_add {
    BushSlicer::Resource.bulk_update(user: admin, resources: _nodes)
    _current_taints = _nodes.map { |n| [n,n.taints] }.to_h
    _diff_taints = _nodes.map do |node|
      [node, _current_taints[node] - _original_taints[node]]
    end.reject {|node, diff_taints| diff_taints.empty?}

    _taint_updates = _diff_taints.map do |node, diff|
      [
        node,
        diff.map do |taint|
          if original = _original_taints[node].find{|t| t.conflicts?(taint)}
            original.cmdline_string
          else
            taint.delete_str
          end
        end
      ]
    end

    _taint_groups = _taint_updates.group_by {|node, updates| updates}.map(&:last)
    _taint_groups.each do |group|
      @result = _admin.cli_exec(
        :oadm_taint_nodes,
        node_name: group.map(&:first).map(&:name),
        overwrite: true,
        key_val: group[0][1]
      )
      raise("failed to revert tainted nodes, see logs") unless @result[:success]
    end

    # verify if the restoration process was succesfull
    BushSlicer::Resource.bulk_update(user: admin, resources: _nodes)
    _current_taints = _nodes.map { |n| [n,n.taints] }.to_h
    _diff_taints = _nodes.map do |node|
      [node, _current_taints[node] - _original_taints[node]]
    end.reject {|node, diff_taints| diff_taints.empty?}
    unless _diff_taints.empty?
      raise "nodes didn't have taints properly restored:\n" \
        "#{_diff_taints.map{ |n,t| "#{n.name}:#{t}" }.join("\n")}"
    end
  }
end

Given /^I run commands on all nodes:$/ do |table|
  transform binding, :table
  ensure_admin_tagged
  @result = BushSlicer::ResultHash.aggregate_results env.node_hosts.map { |host|
    host.exec_admin(table.raw.flatten)
  }
end

Given /^node schedulable status should be restored after scenario$/ do
  ensure_destructive_tagged
  _org_schedulable = env.nodes.map {|n| [n, n.schedulable?]}
  _admin = admin
  teardown_add {
    _org_schedulable.each do |node, schedulable|
      opts = { :node_name =>  node.name }
      if schedulable
        _admin.cli_exec(:oadm_uncordon_node, opts)
      else
        _admin.cli_exec(:oadm_cordon_node, opts)
      end
    end
  }
end

Given /^nodes have #{NUMBER} #{WORD} hugepages configured$/ do |num, word|
  transform binding, :num, :word
  ensure_destructive_tagged
  ensure_admin_tagged
  unless word == "2Mi"
    raise "only 2Mi pages are supported ATM because 1Gi pages " \
      "may need additional kernel parameters and reboot"
  end
  unless env.version_ge("3.10", user: user)
    steps %Q{
      Given feature gate "HugePages" is enabled
    }
  end
  steps %Q{
    Given I select a random node's host
    Given the node service is restarted on the host after scenario
    Given I run commands on the host after scenario:
      | sysctl vm.nr_hugepages=0 && sysctl vm.nr_hugepages  |
    When I run commands on the host:
      | sysctl vm.nr_hugepages=#{num} |
    Then the step should succeed
    When I run commands on the host:
     | sysctl vm.nr_hugepages    |
    Then the step should succeed
    Then the output should contain:
      | #{num}                    |
    Given the node service is restarted on the host
  }
end

Given /^a node that can run pods in the#{OPT_QUOTED} project is selected$/ do |project_name|
  transform binding, :project_name
  ensure_admin_tagged
  selector = project(project_name, generate: false).defined_node_selector
  unless selector
    step %Q{the value with path "['projectConfig']['defaultNodeSelector']" } \
      "in master config is stored into the :defaultnodeselector clipboard"
    selector = cb[:defaultnodeselector].split(",")&.
      map { |l| l.split("=") }&.
      to_h
  end
  selector ||= {} # if no node selector in project and master config
  node = env.nodes.find { |node|
    node.schedulable? && substruct?(selector, node.labels || {})
  }
  if node
    @host = node.host
    cache_resources node
  else
    raise "no suitable node found"
  end
end

Given /^#{QUOTED} is copied to the host(?: under #{QUOTED} path)?$/ do |local_path, remote_path|
  transform binding, :local_path, :remote_path
  @host ||= node.host
  @host.copy_to(local_path, remote_path || "./")
end

# rync local direction dst_dir to a pod, if no pod_name is given the current pod context will be used.
# XXX: should we just hard-code everything to /tmp as the directory.  That seems to be only the only user writable dir
Given /^ssh key for accessing nodes is copied to(?: the #{QUOTED} directory in)? the#{OPT_QUOTED} pod?$/ do |dst_dir, pod_name|
  transform binding, :dst_dir, :pod_name
  ensure_admin_tagged

  pod ||= pod(pod_name)
  _project = project
  dst_dir ||= "tmp"
  pem_file_path = expand_path(env.master_hosts.first[:ssh_private_key])
  FileUtils.mkdir(dst_dir) unless Dir.exists? dst_dir
  FileUtils.copy(pem_file_path, dst_dir)
  @result = admin.cli_exec(:rsync, source: localhost.absolutize(dst_dir), destination: "#{pod.name}:/#{dst_dir}", loglevel: 5, n: _project.name)
  raise "Error syncing files over to '#{pod.name}' pod '#{@result[:stderr]}'" unless @result[:success]
end


Given /^I store all worker nodes to the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  cb_name ||= :worker_nodes
  nodes = BushSlicer::Node.list(user: admin)
  cb[cb_name] = nodes.select { |n| n.is_worker? }
end

Given /^I store the number of worker nodes to the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  nodes = BushSlicer::Node.list(user: admin)
  worker_nodes = nodes.select { |n| n.is_worker? }
  cb[cb_name] = worker_nodes.length
end

Given /^I store the node #{QUOTED} YAML to the#{OPT_SYM} clipboard$/ do |node, cb_name|
  transform binding, :node, :cb_name
  ensure_admin_tagged

  cb_name ||= :deleted_node
  @result = admin.cli_exec(:get, resource: 'node', resource_name: node, o: 'yaml')
  if @result[:success]
    logger.info "node '#{node}' is saved in #{cb_name}"
  else
    raise "could not get node: '#{node}'"
  end

  cb[cb_name] = @result[:response]
end

Given /^the node in the#{OPT_SYM} clipboard is restored from YAML after scenario$/ do |cb_name|
  transform binding, :cb_name
  ensure_admin_tagged

  cb_name ||= :deleted_node
  _admin = admin
  teardown_add {
    @result = _admin.cli_exec(
        :create,
        f: "-",
        _stdin: cb[cb_name]
    )
    # print the whole thing in case we fail
    raise "cannot restore node '#{cb[cb_name]}'" unless @result[:success]
  }
end

Given /^I set all worker nodes status to unschedulable$/ do
  ensure_admin_tagged
  ensure_destructive_tagged
  nodes = env.nodes.select { |n| n.is_worker? }
  nodes.each do |node|
   opts = { :node_name => node.name}
   admin.cli_exec(:oadm_cordon_node, opts)
  end
end
