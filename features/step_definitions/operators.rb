# operators related helper steps
Given /^all clusteroperators reached version #{QUOTED} successfully$/ do |version|
  ensure_admin_tagged
  clusteroperators = BushSlicer::ClusterOperator.list(user: admin)
  clusteroperators.each do | co |
    raise "version does not match #{version}" unless co.version_exists?(version: version)
    # AVAILABLE   PROGRESSING   DEGRADED
    # True        False         False
    conditions = co.conditions
    expected = {"Degraded"=>"False", "Progressing"=>"False", "Available"=>"True"}
    conditions.each do |c|
      # only care about the `expected`, don't compare otherwise
      if expected.keys.include? c['type']
        expected_status = expected[c['type']]
        raise "Failed for condition #{c['type']}, expected: #{expected_status}, got: #{c['status']}" unless expected_status == c['status']
      end
    end
  end
end

Given /^the status of condition "([^"]*)" for "([^"]*)" operator is: (.+)$/ do | type, operator, status |
  ensure_admin_tagged
  actual_status = cluster_operator(operator).condition(type: type, cached: false)['status']
  unless status == actual_status
    raise "status of #{operator} condition #{type} is #{actual_status}"
  end
end

Given /^I create a new CatalogSourceConfig$/ do
  ensure_admin_tagged
  # Create CatalogSourceConfig in 4.5-
  if env.version_lt("4.5", user: user)
    csc_yaml ||= "#{BushSlicer::HOME}/testdata/olm/csc-template.yaml"
    step %Q/I process and create:/, table(%{
      | f | #{csc_yaml}                 |
      | p | PACKAGES=codeready-toolchain-operator     |
      | p | DISPLAYNAME=CSC Operators                 |
    })
    raise "Error creating CatalogSourceConfig" unless @result[:success]
  end
end

Given /^I create a new OperatorSource$/ do
  ensure_admin_tagged
  step %Q/I use the "openshift-marketplace" project/
  # Create OperatorSource in 4.6-
  if env.version_lt("4.6", user: user)
    os_yaml ||= "#{BushSlicer::HOME}/testdata/olm/operatorsource-template.yaml"
    step %Q/I process and create:/, table(%{
      | f | #{os_yaml}                 |
      | p | NAME=test-operators          |
      | p | SECRET=                      |
      | p | DISPLAYNAME=Test Operators   |
      | p | REGISTRY=jiazha              |
    })
    raise "Error creating OperatorSource" unless @result[:success]
  end
end

Given /^the marketplace works well$/ do
  ensure_admin_tagged
  if env.version_lt("4.5", user: user)
    step %Q/I run the :get admin command with:/, table(%{
      | resource       | packagemanifest |
      | all_namespaces | true            |
    })
    step %Q/the output should contain:/, table(%{
      | Community Operators  |
      | Red Hat Operators    |
      | Certified Operators  |
      | Test Operators       |
      | CSC Operators        |
    })
  elsif env.version_eq("4.5", user: user)
    step %Q/I run the :get client command with:/, table(%{
      | resource       | packagemanifest |
      | all_namespaces | true            |
    })
    step %Q/the output should contain:/, table(%{
      | Community Operators  |
      | Red Hat Operators    |
      | Certified Operators  |
      | Test Operators       |
    })
  else
    step %Q/I run the :get client command with:/, table(%{
      | resource       | packagemanifest |
      | all_namespaces | true            |
    })
    step %Q/the output should contain:/, table(%{
      | Community Operators  |
      | Red Hat Operators    |
      | Certified Operators  |
    })
  end
end

Given /^the status of condition Upgradeable for marketplace operator as expected$/ do
  ensure_admin_tagged
  if env.version_eq("4.1", user: user) || env.version_ge("4.6", user: user)
    actual_status = 'True'
  else
    actual_status = cluster_operator('marketplace').condition(type: 'Upgradeable', cached: false)['status']
  end
  status = 'True'
  if env.version_eq("4.4", user: user) || env.version_eq("4.5", user: user)
    csc_items = Array.new
    os_items = Array.new
    if custom_resource_definition('catalogsourceconfigs.operators.coreos.com').exists?
      @result = admin.cli_exec(:get, resource: 'catalogsourceconfig', all_namespaces: 'true', o: 'yaml')
      raise "Unable to get CSC resource" unless @result[:success]
      csc_items = @result[:parsed]['items']
      logger.info("=== CSC exists in this cluster!")
    end
    if custom_resource_definition('operatorsources.operators.coreos.com').exists?
      @result = admin.cli_exec(:get, resource: 'operatorsource', all_namespaces: 'true', o: 'yaml')
      raise "Unable to get OperatorSource resource" unless @result[:success]
      os_items = @result[:parsed]['items']
      logger.info("=== OperatorSource exists in this cluster! items: #{os_items.count}")
    end

    if !csc_items.empty? or (os_items.count > 4)
      status = 'False'
      @result = admin.cli_exec(:get, resource: "clusterversion", resource_name: "version", o: "jsonpath={.status.desired.version}")
      cluster_version = @result[:response]
      logger.info("=== #{cluster_version} cluster. And customize OperatorSource or csc objects exist, change the expected status to False")
    end
  end
  unless status == actual_status
    raise "status of marketplace condition Upgradeable is #{actual_status}"
  end
end

Given /^the "([^"]*)" operator version matches the current cluster version$/ do | operator |
  ensure_admin_tagged
  @result = admin.cli_exec(:get, resource: "clusteroperators", resource_name: operator, o: "jsonpath={.status.versions[?(.name == \"operator\")].version}")
  operator_version = @result[:response]

  @result = admin.cli_exec(:get, resource: "clusterversion", resource_name: "version", o: "jsonpath={.status.desired.version}")
  cluster_version = @result[:response]

  raise "The #{operator} version doesn't match the current cluster version" unless operator_version == cluster_version
  logger.info("### the cluster version is #{cluster_version}")
end

Given /^admin updated the operator crd "([^"]*)" managementstate operand to (Managed|Removed|Unmanaged)$/ do |cluster_operator, manage_type|
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

# Get the Major.Minor cluster version
Given /^the major.minor version of the cluster is stored in the#{OPT_SYM} clipboard$/ do | cb_name |
  cb_name = 'operator_channel_name' unless cb_name
  cb[cb_name] = cluster_version('version').channel.split('-')[1]
end

Given /^operator #{QUOTED} becomes #{NO_SPACE_STR}(?: within #{NUMBER} seconds)?$/ do | operator_name, conditions, timeout |
  ensure_admin_tagged

  expected = {}
  interval_time = 5
  timeout = Integer(timeout) rescue 60
  interval_time = 20 if timeout > 100
  actual_results = {}
  stats = {}

  # Parse the conditions to Hash table {Available"=>"True", "Progressing"=>"False", "Degraded"=>"False"}
  arr_conditions = conditions.split("/")
  arr_conditions.each do |v|
    case v
    when /^(available|non-available)$/
      (v.include? "non-") ? expected["Available"] = "False" : expected["Available"] = "True"
    when /^(progressing|non-progressing)$/
      (v.include? "non-") ? expected["Progressing"] = "False" : expected["Progressing"] = "True"
    when /^(degraded|non-degraded)$/
      (v.include? "non-") ? expected["Degraded"] = "False" : expected["Degraded"] = "True"
    else
      raise "#### Invalid condition: #{v}, please input one or more condition(s) of (available|non-available)/(progressing|non-progressing)/(degraded|non-degraded) !"
    end
  end
  raise "#### Without any conditions, please input at least one condition!!!" unless expected.length >0

  begin
    # Log to StdOut dedup
    logger.dedup_start
    success = wait_for(timeout, interval: interval_time, stats: stats) {
      # Does not get conditions data from the cache
      current_conditions = cluster_operator(operator_name).conditions(cached: false)
      expected.keys.each do |c|
        actual_results[c] = current_conditions.select{ |t| t['type'] == c }.first['status']
      end
      expected == actual_results
    }
    logger.info("#### Operator #{operator_name} Expected conditions: #{expected}")
    logger.info "#### After #{stats[:seconds]} seconds and #{stats[:iterations]} iterations " <<
      "operator #{operator_name} becomes: #{actual_results}" if success
    raise "The #{operator_name} operator still didn't become #{expected} after #{timeout} seconds" unless success
  ensure
    logger.dedup_flush
  end
end
