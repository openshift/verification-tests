Feature: service upgrade scenarios

  # @author zzhao@redhat.com
  @admin
  @upgrade-prepare
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @disconnected @connected
  Scenario: Check the idle service works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | idle-upgrade |
    Then the step should succeed
    When I use the "idle-upgrade" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    When I run the :idle client command with:
      | svc_name | test-service |
    Then the step should succeed
    And I wait until number of replicas match "0" for replicationController "test-rc"
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | test-service.*none |

  # @author zzhao@redhat.com
  # @case_id OCP-44259
  @admin
  @upgrade-check
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: Check the idle service works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "idle-upgrade" project
    When I run the :get client command with:
      | resource | endpoints |
    Then the step should succeed
    And the output should match:
      | test-service.*none |
    Given I use the "test-service" service
    And evaluation of `service.url(user: user)` is stored in the :service_url clipboard
    Given I have a pod-for-ping in the project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 30 | <%= cb.service_url %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |
    """

  # @author zzhao@redhat.com
  @admin
  @upgrade-prepare
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @disconnected @connected
  Scenario: Check the nodeport service works well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | nodeport-upgrade |
    Then the step should succeed
    And evaluation of `rand(30000..32767)` is stored in the :port clipboard
    When I use the "nodeport-upgrade" project
    Given I obtain test data file "networking/nodeport_test_pod.yaml"
    When I run the :create client command with:
      | f | nodeport_test_pod.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=hello-pod |
    When I obtain test data file "networking/nodeport_test_service.yaml"
    When I run oc create over "nodeport_test_service.yaml" replacing paths:
      | ["spec"]["ports"][0]["nodePort"] | <%= cb.port %> |
    Then the step should succeed

    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.node_ip` is stored in the :hostip clipboard
    When I execute on the pod:
      | curl | <%= cb.hostip %>:<%= cb.port %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |

  # @author zzhao@redhat.com
  # @case_id OCP-44302
  @admin
  @upgrade-check
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn @network-networkpolicy
  Scenario: Check the nodeport service works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "nodeport-upgrade" project
    Given I use the "hello-pod" service
    And a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.node_ip` is stored in the :hostip clipboard
    When I execute on the pod:
      | curl | <%= cb.hostip %>:<%= service.ports[0]["nodePort"] %> |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift! |
