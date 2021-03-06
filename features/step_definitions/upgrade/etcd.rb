Given /^etcd operator "([^"]*)" is removed successfully from "([^"]*)" project$/ do | name, proj_name|
  transform binding, :name, :proj_name
  ensure_admin_tagged
  raise "!!! Error doesn't exist etcd operator: #{name} in this #{proj_name} project" unless subscription("#{name}").exists?
  step %Q/I ensure "#{name}" subscription is deleted from the "#{proj_name}" project/

  step %Q/I run the :delete client command with:/, table(%{
    | object_type       | clusterserviceversion |
    | all               |                       |
    | n                 | #{proj_name}          |
  })
  raise "Error removing CSV: #{name} in #{proj_name} project" unless @result[:success]

  step %Q/I ensure "etcd-operator" deployment is deleted from the "#{proj_name}" project/
  logger.info("### etcd operator: #{name} is removed successfully from #{proj_name} namespace")

end

Given /^etcd operator "([^"]*)" is installed successfully in "([^"]*)" project$/ do | name, proj_name|
  transform binding, :name, :proj_name
    ensure_admin_tagged
    step %Q/I switch to cluster admin pseudo user/
    step %Q/I use the "#{proj_name}" project/
    unless operator_group('etcd-og').exists?
      # Create operator group in this namespace
      operator_group_yaml ||= "#{BushSlicer::HOME}/testdata/olm/operatorgroup-template.yaml"
      step %Q/I process and create:/, table(%{
        | f | #{operator_group_yaml} |
        | p | NAME=etcd-og         |
        | p | NAMESPACE=#{proj_name} |
      })
      raise "Error creating OperatorGroup: etcd-og" unless @result[:success]
    end
    logger.info("### operator group: etcd-og is installed successfully in #{proj_name} namespace")

    unless subscription("#{name}").exists?
      # Subscribe etcd operator
      sub_etcd_yaml ||= "#{BushSlicer::HOME}/testdata/olm/etcd-subscription-template.yaml"
      step %Q/I process and create:/, table(%{
        | f | #{sub_etcd_yaml}                      |
        | p | NAME=#{name}                          |
        | p | NAMESPACE=#{proj_name}                |
        | p | SOURCENAME=community-operators        |
        | p | SOURCENAMESPACE=openshift-marketplace |
      })
      raise "Error creating subscription: #{name}" unless @result[:success]
    end

    step %Q/I wait for the "etcd-operator" deployment to appear/
    step %Q/a pod becomes ready with labels:/, table(%{
      | name=etcd-operator-alm-owned |
    })
    raise "Error creating #{name} pods in #{proj_name} project" unless @result[:success]

    step %Q/I run the :get client command with:/, table(%{
      | resource | etcdcluster |
    })
    step %Q/the output should contain "No resources found"/
    raise "Error find the etcdCluster resource in #{proj_name} project" unless @result[:success]
    logger.info("### etcd operator: #{name} is installed successfully in #{proj_name} namespace")
end

Given /^etcdCluster "([^"]*)" is installed successfully in "([^"]*)" project$/ do | name, proj_name|
  transform binding, :name, :proj_name
  step %Q/I use the "#{proj_name}" project/
  etcdCluster_yaml ||= "#{BushSlicer::HOME}/testdata/olm/etcd-cluster-template.yaml"
  step %Q/I process and create:/, table(%{
    | f | #{etcdCluster_yaml} |
    | p | NAME=#{name}         |
    | p | NAMESPACE=#{proj_name} |
  })
  raise "Error creating etcdCluster: #{name} in project: #{proj_name}" unless @result[:success]
  logger.info("### etcdCluster: #{name} is installed successfully in #{proj_name} namespace")
end

Given /^etcdCluster "([^"]*)" is removed successfully from "([^"]*)" project$/ do | name, proj_name|
  transform binding, :name, :proj_name
  step %Q/I ensure "#{name}" etcd_cluster is deleted from the "#{proj_name}" project/
  logger.info("### etcdCluster: #{name} is removed successfully from #{proj_name} namespace")
end


