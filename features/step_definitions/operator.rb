Given /^Admin updated the operator crd "([^"]*)" managementstate operand to (Managed|Removed|Unmanaged)$/ do |cluster_operator, manage_type|
  ensure_admin_tagged
  ensure_destructive_tagged
  step %Q/I run the :patch admin command with:/, table(%{
    | resource      | #{cluster_operator}.operator.openshift.io      |
    | resource_name | cluster                                        |
    | p             | {"spec":{"managementState": "#{manage_type}"}} |
    | type          | merge                                          |
  })
  step %Q/the step should succeed/
end

Given /^etcd operator "([^"]*)" is removed successfully from "([^"]*)" project$/ do | name, proj_name|
  ensure_admin_tagged
  step %Q/I use the "#{proj_name}" project/
  raise "!!! Error doesn't exist etcd operator: #{name} in this #{proj_name} project" unless subscription("#{name}").exists?
  step %Q/I run the :delete client command with:/, table(%{
    | object_type       | subscription |
    | object_name_or_id | #{name}      |
  })
  raise "Error removing subscription: #{name} in #{proj_name} project" unless @result[:success]

  step %Q/I run the :delete client command with:/, table(%{
    | object_type       | clusterserviceversion |
    | object_name_or_id | etcdoperator.v0.9.4   |
  })
  raise "Error removing CSV: #{name} in #{proj_name} project" unless @result[:success]

  step %Q/I run the :delete client command with:/, table(%{
    | object_type       | deployment |
    | object_name_or_id | etcd-operator   |
  })
  step %Q/I wait for the resource "deployment" named "etcd-operator" to disappear within 180 seconds/
  logger.info("### etcd operator: #{name} is removed successfully from #{proj_name} namespace")

end

Given /^etcd operator "([^"]*)" is installed successfully in "([^"]*)" project$/ do | name, proj_name|
    ensure_admin_tagged
    step %Q/I switch to cluster admin pseudo user/
    step %Q/I use the "#{proj_name}" project/
    unless operator_group('etcd-og').exists?
      # Create operator group in this namespace
      operator_group_yaml ||= "https://raw.githubusercontent.com/jianzhangbjz/v3-testfiles/olm-upgrade/olm/operatorgroup-template.yaml"
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
      sub_etcd_yaml ||= "https://raw.githubusercontent.com/openshift/origin/master/test/extended/testdata/olm/etcd-subscription.yaml"
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
  step %Q/I use the "#{proj_name}" project/
  etcdCluster_yaml ||= "https://raw.githubusercontent.com/openshift/origin/master/test/extended/testdata/olm/etcd-cluster.yaml"
  step %Q/I process and create:/, table(%{
    | f | #{etcdCluster_yaml} |
    | p | NAME=#{name}         |
    | p | NAMESPACE=#{proj_name} |
  })
  raise "Error creating etcdCluster: #{name} in project: #{proj_name}" unless @result[:success]
  logger.info("### etcdCluster: #{name} is installed successfully in #{proj_name} namespace")

end

Given /^etcdCluster "([^"]*)" is removed successfully from "([^"]*)" project$/ do | name, proj_name|
  step %Q/I run the :delete client command with:/, table(%{
    | object_type       | etcdcluster  | 
    | object_name_or_id | #{name}      |
    | n                 | #{proj_name} |      
  })
  step %Q/the output should contain "deleted"/
  step %Q/I wait for the resource "etcdcluster" named "#{name}" to disappear within 180 seconds/
  step %Q/I run the :get client command with:/, table(%{
    | resource      | etcdcluster  | 
    | resource_name | #{name}      |
    | n             | #{proj_name} |      
  })
  step %Q/the output should contain "NotFound"/
  logger.info("### etcdCluster: #{name} is removed successfully from #{proj_name} namespace")

end

Given /^The status of condition "([^"]*)" for "([^"]*)" operator is: (.+)$/ do | type, operator, status |
  ensure_admin_tagged
  expected_status = status

  if type == "Available"
    @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: operator, o: "jsonpath={.status.conditions[?(.type == \"Available\")].status}")
    real_status = @result[:response]
  elsif type == "Progressing"
    @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: operator, o: "jsonpath={.status.conditions[?(.type == \"Progressing\")].status}")
    real_status = @result[:response]
  elsif type == "Degraded"
    @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: operator, o: "jsonpath={.status.conditions[?(.type == \"Degraded\")].status}")
    real_status = @result[:response]
  elsif type == "Upgradeable"
    @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: operator, o: "jsonpath={.status.conditions[?(.type == \"Upgradeable\")].status}")
    real_status = @result[:response]
  else
    raise "Unknown condition type!"
  end

  raise "The status of condition #{type} is incorrect." unless expected_status == real_status
end

Given /^The "([^"]*)" operator version matchs the current cluster version$/ do | operator |
  ensure_admin_tagged
  @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: operator, o: "jsonpath={.status.versions[?(.name == \"operator\")].version}")
  operator_version = @result[:response]

  @result = admin.cli_exec(:get, resource: "clusterversion", resource_name: "version", o: "jsonpath={.status.desired.version}")
  cluster_version = @result[:response]

  raise "The #{operator} version doesn't match the current cluster version" unless operator_version == cluster_version
  logger.info("### the cluster version is #{cluster_version}")

end
