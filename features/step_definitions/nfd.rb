Given /^the nfd-operator is installed(?: to #{OPT_QUOTED})? using OLM(?: (CLI|GUI))?$/ do | nfd_ns, install_method |
  ensure_admin_tagged
  nfd_ns ||= "openshift-nfd"
  if install_method == 'GUI'
    nfd_ns = "openshift-operators"
  end
  cb.channel = cluster_version('version').version.split('-')[0].to_f
  install_method ||= 'CLI'
  step %Q/the first user is cluster-admin/
  step %Q/I ensure "#{nfd_ns}" project is deleted after scenario/
  if install_method == 'GUI'
    cb.project = project(nfd_ns)
    step %Q/I open admin console in a browser/
    step %Q/the step should succeed/
    step %Q/I perform the :goto_operator_subscription_page web action with:/, table(%{
      | package_name     | nfd                    |
      | catalog_name     | qe-app-registry        |
      | target_namespace | <%= cb.project.name %> |
    })
    step %Q/the step should succeed/
    step %Q/I perform the :set_custom_channel_and_subscribe web action with:/, table(%{
      | update_channel    | <%= cb.channel %> |
      | install_mode      | OwnNamespace      |
      | approval_strategy | Automatic         |
    })
    step %Q/the step should succeed/
    step %Q/I use the "#{nfd_ns}" project/
    # must make sure the nfd-operator pod is `Running`
    step %Q/a pod becomes ready with labels:/, table(%{
      | name=nfd-operator |
    })
    step %Q|I run oc create over ERB test file: nfd/<%= cb.channel %>/nfd_master.yaml|
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
    # must make sure the nfd-operator pod is `Running`
    step %Q/a pod becomes ready with labels:/, table(%{
      | name=nfd-operator |
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
end
