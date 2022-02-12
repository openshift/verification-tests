Given /^the nfd-operator is installed(?: to #{OPT_QUOTED})? using OLM(?: (CLI|GUI))?$/ do | nfd_ns, install_method |
  ensure_admin_tagged
  nfd_ns ||= "openshift-nfd"
  if install_method == 'GUI'
    nfd_ns = "openshift-nfd"
  end
  ver_raw, ver_major, ver_minor = env.get_version(user: user)
  cb.channel = (ver_major.to_s + "." + ver_minor.to_s)
  install_method ||= 'CLI'
  step %Q/the first user is cluster-admin/
  step %Q/admin ensure "#{nfd_ns}" project is deleted after scenario/
  step %Q/admin ensure "nfd-master-server" node_feature_discovery is deleted from the "#{nfd_ns}" project after scenario/
  pod_label = "name=nfd-operator"
  pod_label = "control-plane=controller-manager" if env.version_gt("4.7", user: user)
  if install_method == 'GUI'
    # for 4.6, the GUI doesn't create the ns automatically if not present, so
    # do it manually
    if env.version_lt("4.7", user: user)
      admin.cli_exec(:create_namespace, name: nfd_ns)
      step %Q/I wait for the "#{nfd_ns}" project to appear/
      step %Q/I use the "#{nfd_ns}" project/
    end
    cb.project = project(nfd_ns)
    step %Q/I open admin console in a browser/
    step %Q/the step should succeed/
    step %Q/I perform the :goto_operator_subscription_page web action with:/, table(%{
      | package_name     | nfd                    |
      | catalog_name     | qe-app-registry        |
      | target_namespace | <%= cb.project.name %> |
    })
    step %Q/the step should succeed/
    if env.version_gt("4.8", user: user)
      channel_button = "stable"
    else
      channel_button = cb.channel
    end
    step %Q/I perform the :set_custom_channel_and_subscribe web action with:/, table(%{
      | update_channel    | #{channel_button} |
      | install_mode      | OwnNamespace      |
      | approval_strategy | Automatic         |
    })
    step %Q/the step should succeed/

    logger.info("Make sure pod is running with #{pod_label}")
    # must make sure the nfd-operator pod is `Running`
    step %Q/a pod becomes ready with labels:/, table(%{
      | #{pod_label} |
    })
    step %Q|I run oc create over ERB test file: nfd/<%= cb.channel %>/040_customresources.yaml|
    step %Q/the step should succeed/
  else
    file_path = "nfd/#{cb.channel}/010_namespace.yaml"
    step %Q(I run oc create over ERB test file: #{file_path})
    step %Q(the step should succeed)
    file_path = "nfd/#{cb.channel}/020_operatorgroup.yaml"
    step %Q(I run oc create over ERB test file: #{file_path})
    step %Q(the step should succeed)
    file_path = "nfd/#{cb.channel}/030_operator_sub.yaml"
    step %Q(I run oc create over ERB test file: #{file_path})
    step %Q(the step should succeed)
    project(nfd_ns)
    # must make sure the nfd-operator pod is `Running`
    step %Q/a pod becomes ready with labels:/, table(%{
      | #{pod_label} |
    })
    file_path = "nfd/#{cb.channel}/040_customresources.yaml"
    step %Q(I run oc create over ERB test file: #{file_path})
    step %Q(the step should succeed)
  end
  ###
  #  You should also see in openshift-nfd namespace the following pods running:
  # - nfd-operator pod
  # - 3 master-nfd pods
  # - one worker nfd pod for each worker node
  step %Q/all the pods in the project reach a successful state/
  step %Q/I store all worker nodes to the :worker_nodes clipboard/
  step %Q/I store the masters in the :master_nodes clipboard/
  step %Q/<%= cb.master_nodes.count %> pods become ready with labels:/, table(%{
    | app=nfd-master |
  })
  step %Q/<%= cb.master_nodes.count %> pods become ready with labels:/, table(%{
    | app=nfd-worker |
  })

  # All the worker nodes should get labeled as well:
  # go through all nodes and check if there are labels starts with 'feature'
  node_labels = cb.worker_nodes.select {|w| w.labels.select {|n| n.start_with? 'feature'}}
  raise "Node labled check failed" unless node_labels.count > 0
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-nfd" project/

  logger.info("Check nfd resource exists...")
  raise "NodeFeatureDiscovery resource does not exists" unless node_feature_discovery('nfd-master-server').exists?
end
