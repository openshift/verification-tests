Feature: web console related upgrade check

  # @author yanpzhan@redhat.com
  @console
  @upgrade-prepare
  @users=upuser1,upuser2
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @admin
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: check console accessibility - prepare
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | ui-upgrade |
    Then the step should succeed
    Given I use the "ui-upgrade" project
    Given I obtain test data file "daemon/daemonset.yaml"
    When I run the :create client command with:
      | f | daemonset.yaml |
    Then the step should succeed
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    Given I obtain test data file "deployment/hello-deployment-1.yaml"
    When I run the :create client command with:
      | f | hello-deployment-1.yaml |
    Then the step should succeed
    Given I open admin console in a browser
    When I perform the :goto_deployment_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-openshift |
    Then the step should succeed
    When I perform the :goto_dc_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hooks |
    Then the step should succeed
    When I perform the :goto_daemonsets_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-daemonset |
    Then the step should succeed

  # @author yanpzhan@redhat.com
  # @case_id OCP-22597
  @upgrade-check
  @admin
  @console
  @users=upuser1,upuser2
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: check console accessibility
    Given the first user is cluster-admin
    Given I open admin console in a browser
    When I perform the :goto_deployment_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-openshift |
    Then the step should succeed
    When I perform the :goto_dc_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hooks |
    Then the step should succeed
    When I perform the :goto_daemonsets_page web action with:
      | project_name | ui-upgrade |
    Then the step should succeed
    When I perform the :check_resource_item_name web action with:
      | resource_name | hello-daemonset |
    Then the step should succeed
