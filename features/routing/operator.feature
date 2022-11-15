Feature: Testing Ingress Operator related scenarios

  # @author hongli@redhat.com
  # @case_id OCP-27594
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-27594:NetworkEdge set namespaceOwnership of routeAdmission to InterNamespaceAllowed
    Given the master version >= "4.4"
    And I have a project
    And I store default router subdomain in the :subdomain clipboard
    Given I switch to cluster admin pseudo user
    And admin ensures "test-27594" ingresscontroller is deleted from the "openshift-ingress-operator" project after scenario
    Given I obtain test data file "routing/operator/ingressctl-nsowner.yaml"
    When I run oc create over "ingressctl-nsowner.yaml" replacing paths:
      | ["metadata"]["name"] | test-27594                                    |
      | ["spec"]["domain"]   | <%= cb.subdomain.gsub("apps","test-27594") %> |
    Then the step should succeed

    # check the env in the router pod
    Given I use the "openshift-ingress" project
    And a pod becomes ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=test-27594 |
    And evaluation of `pod.name` is stored in the :router_pod clipboard
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | env |
    Then the output should contain:
      | ROUTER_DISABLE_NAMESPACE_OWNERSHIP_CHECK=true |
    """

    # create route in the first namespace
    Given I switch to the first user
    And I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    Given the pod named "web-server-1" becomes ready
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | service          |
      | resource_name | service-unsecure |
      | path          | /test            |
    Then the step should succeed
    Given evaluation of `route("service-unsecure", service("service-unsecure")).dns(by: user)` is stored in the :unsecure clipboard

    # switch to another user/namespace and create one same hostname with different path
    Given I switch to the second user
    And I have a project
    Given I obtain test data file "routing/web-server-1.yaml"
    When I run the :create client command with:
      | f | web-server-1.yaml |
    Then the step should succeed
    Given the pod named "web-server-1" becomes ready
    And evaluation of `pod.ip` is stored in the :pod_ip clipboard
    Given I obtain test data file "routing/service_unsecure.yaml"
    When I run the :create client command with:
      | f | service_unsecure.yaml |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | service            |
      | resource_name | service-unsecure   |
      | hostname      | <%= cb.unsecure %> |
      | path          | /path/second       |
    Then the step should succeed

    # ensure the second route is admitted
    Given I switch to cluster admin pseudo user
    And I use the "openshift-ingress" project
    And I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.router_pod %>" pod:
      | grep | <%= cb.pod_ip %> |/var/lib/haproxy/conf/haproxy.config |
    Then the step should succeed
    """

