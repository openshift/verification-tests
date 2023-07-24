@clusterlogging
Feature: Kibana related features

  # @author qitang@redhat.com
  # @case_id OCP-25599
  @admin
  @console
  @destructive
  @commonlogging
  @proxy @noproxy @disconnected @connected
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @network-openshiftsdn
  @critical
  Scenario: OCP-25599:Logging Show logs on Kibana web console according to different user role
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given I switch to cluster admin pseudo user
    Given I use the "openshift-logging" project
    And I wait for the "kibana" route to appear
    And I wait for the "project.<%= cb.proj.name %>" index to appear in the ES pod with labels "es-node-master=true"
    Given I switch to the first user
    And I login to kibana logging web console
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | project.<%= cb.proj.name %>.<%= cb.proj.uid %>.* |
    Then the step should succeed
    When I run the :logout_kibana web action
    Then the step should succeed
    And I close the current browser
    Given cluster role "cluster-admin" is added to the "first" user
    Then I login to kibana logging web console
    Given evaluation of `[".operations.*", ".all", ".orphaned", "project.*"]` is stored in the :indices clipboard
    And I run the :kibana_expand_index_patterns web action
    Then the step should succeed
    Given I repeat the following steps for each :index_name in cb.indices:
    """
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | #{cb.index_name} |
    Then the step should succeed
    """
    When I run the :logout_kibana web action
    Then the step should succeed
    And I close the current browser
    And cluster role "cluster-admin" is removed from the "first" user

    And I login to kibana logging web console
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | project.<%= cb.proj.name %>.<%= cb.proj.uid %>.* |
    Then the step should succeed
    And I run the :kibana_expand_index_patterns web action
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | .operations.* |
    Then the step should fail

  # @author qitang@redhat.com
  # @case_id OCP-30362
  @admin
  @console
  @destructive
  @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @logging5.6 @logging5.7 @logging5.8 @logging5.5
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-30362:Logging Normal User can only view logs out of the projects owned by himself --kibana
    Given the correct directory name of clusterlogging file is stored in the :cl_dir clipboard
    And I obtain test data file "logging/clusterlogging/<%= cb.cl_dir %>/example_indexmanagement.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true                         |
      | crd_yaml            | example_indexmanagement.yaml |
    Then the step should succeed
    Given I switch to the first user
    And I create a project with non-leading digit name
    And evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    Given I switch to the first user
    When I login to kibana logging web console
    Then the step should succeed
    Given I have index pattern "app"
    Then the step should succeed
    Given I wait up to 300 seconds for the steps to pass:
    """
    And I run the :go_to_kibana_discover_page web action
    Then the step should succeed
    """
    # check the log count, wait for the Kibana console to be loaded
    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | app* |
    Then the step should succeed
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I run the :check_log_count web action
    Then the step should succeed
    """
    # Verify the token are encrypted in kibana logs
    Given I switch to cluster admin pseudo user
    And I use the "openshift-logging" project
    Given a pod becomes ready with labels:
      | logging-infra=kibana |
    When I run the :logs client command with:
      | resource_name | <%= pod.name %> |
      | c             | kibana          |
    Then the output should contain:
      | "x-forwarded-access-token":"XXXXXXXXXXXXXX |
      | "x-forwarded-email":"XXXXXXXXXXXXXX        |

  # @author qitang@redhat.com
  # @case_id OCP-30361
  @admin
  @console
  @destructive
  @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @logging5.6 @logging5.7 @logging5.8
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-30361:Logging User with cluster-admin role can show logs out of all projects -- kibana
    Given the correct directory name of clusterlogging file is stored in the :cl_dir clipboard
    And I obtain test data file "logging/clusterlogging/<%= cb.cl_dir %>/example_indexmanagement.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true                         |
      | crd_yaml            | example_indexmanagement.yaml |
    Then the step should succeed
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project` is stored in the :proj clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given I switch to the second user
    And the second user is cluster-admin
    And I use the "openshift-logging" project
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    Given I wait for the "infra" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj.name %>" logs to appear in the ES pod
    When I login to kibana logging web console
    Then the step should succeed
    Given I have index pattern "app"
    Then the step should succeed
    And I have index pattern "infra"
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    And I run the :go_to_kibana_discover_page web action
    Then the step should succeed
    """

    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | app* |
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run the :check_log_count web action
    Then the step should succeed
    """
    And I run the :kibana_expand_index_patterns web action
    Then the step should succeed
    When I perform the :kibana_click_index web action with:
      | index_pattern_name | infra* |
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | infra* |
    Then the step should succeed
    When I run the :check_log_count web action
    Then the step should succeed
    """

  # @author qitang@redhat.com
  # @case_id OCP-32002
  @admin
  @console
  @destructive
  @commonlogging
  @singlenode
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  Scenario: OCP-32002:Logging Kibana logout function should log off user
    Given the master version < "4.5"
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project.name` is stored in the :proj_name clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    Given the first user is cluster-admin
    And I use the "openshift-logging" project
    And I wait for the "project.<%= cb.proj_name %>" index to appear in the ES pod with labels "es-node-master=true"
    And evaluation of `route('kibana', service('kibana',project('openshift-logging', switch: false))).dns(by: admin)` is stored in the :kibana_url clipboard
    When I login to kibana logging web console
    Then the step should succeed
    And I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | .operations.* |
    Then the step should succeed
    When I run the :logout_kibana web action
    Then the step should succeed
    Given 10 seconds have passed
    When I access the "https://<%= cb.kibana_url %>" url in the web browser
    Then the step should succeed
    When I perform the :login_kibana web action with:
      | username   | <%= user.name %>             |
      | password   | <%= user.password %>         |
      | idp        | <%= env.idp %>               |
    Then the step should succeed
    # click `Log in with OpenShift` button and login again
    When I run the :logout_kibana web action
    Then the step should succeed
    When I perform the :login_kibana web action with:
      | username   | <%= user.name %>             |
      | password   | <%= user.password %>         |
      | idp        | <%= env.idp %>               |
    Then the step should succeed

  # @author gkarager@redhat.com
  # @case_id OCP-30343
  @admin
  @destructive
  @console
  @proxy @noproxy @disconnected @connected
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @logging5.6 @logging5.7 @logging5.8 @logging5.5
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-30343:Logging Logs can be redirected from Webconsole to kibana
    Given the correct directory name of clusterlogging file is stored in the :cl_dir clipboard
    And I obtain test data file "logging/clusterlogging/<%= cb.cl_dir %>/example_indexmanagement.yaml"
    When I create clusterlogging instance with:
      | remove_logging_pods | true                         |
      | crd_yaml            | example_indexmanagement.yaml |
    Then the step should succeed
    Given I switch to the first user
    Given I create a project with non-leading digit name
    Given evaluation of `project.name` is stored in the :proj_name clipboard
    Given I obtain test data file "logging/loggen/container_json_log_template.json"
    When I run the :new_app client command with:
      | file | container_json_log_template.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=centos-logtest,test=centos-logtest |
    And evaluation of `pod.name` is stored in the :pod_name clipboard
    Given the first user is cluster-admin
    And I use the "openshift-logging" project
    Given I wait for the "app" index to appear in the ES pod with labels "es-node-master=true"
    Given I wait for the "infra" index to appear in the ES pod with labels "es-node-master=true"
    And I wait for the project "<%= cb.proj_name %>" logs to appear in the ES pod

    When I run the :get client command with:
      | resource | ConsoleExternalLogLink   |
    Then the step should succeed

    And I open admin console in a browser
    When I perform the :goto_one_pod_log_page web action with:
      | project_name | <%= cb.proj_name %> |
      | pod_name     | <%= cb.pod_name %>  |
    Then the step should succeed

    When I click the following "a" element:
      | text  | Show in Kibana   |
      | class | co-external-link |
    Then the step should succeed

    # This step is to store the redirecting url of new window, does not check anything
    And I wait up to 15 seconds for the steps to pass:
    """
    When I perform the :check_page_contains web action in ":url=>oauth" window with:
      | content | |
    Then the step should succeed
    And evaluation of `@result[:url]` is stored in the :oauth_login clipboard
    """
    When I access the "<%= cb.oauth_login %>" url in the web browser

    When I perform the :login_kibana web action with:
      | username   | <%= user.name %>             |
      | password   | <%= user.password %>         |
      | idp        | <%= env.idp %>               |
    Then the step should succeed

    Given I have index pattern "app"
    Then the step should succeed
    Given I have index pattern "infra"
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    And I run the :go_to_kibana_discover_page web action
    Then the step should succeed
    """

    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | app* |
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I run the :check_log_count web action
    Then the step should succeed
    """
    And I run the :kibana_expand_index_patterns web action
    Then the step should succeed
    When I perform the :kibana_click_index web action with:
      | index_pattern_name | infra* |
    Then the step should succeed
    Given I wait up to 180 seconds for the steps to pass:
    """
    When I perform the :kibana_find_index_pattern web action with:
      | index_pattern_name | infra* |
    Then the step should succeed
    When I run the :check_log_count web action
    Then the step should succeed
    """
