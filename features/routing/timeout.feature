Feature: Testing timeout route

  # @author yadu@redhat.com
  # @case_id OCP-11635
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @rosa @osd_ccs @aro
  @critical
  @hypershift-hosted
  Scenario: OCP-11635:NetworkEdge Set timeout server for passthough route
    Given I have a project
    Given I obtain test data file "routing/routetimeout/httpbin-pod.json"
    When I run the :create client command with:
      | f  | httpbin-pod.json |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=httpbin-pod |
    Given I obtain test data file "routing/routetimeout/passthough/service_secure.json"
    When I run the :create client command with:
      | f  | service_secure.json |
    Then the step should succeed
    Given I wait for the "service-secure" service to become ready
    When I run the :create_route_passthrough client command with:
      | name     | pass-route       |
      | service  | service-secure |
    Then the step should succeed
    When I run the :annotate client command with:
      | resource         | route                                  |
      | resourcename     | pass-route                             |
      | overwrite        | true                                   |
      | keyval           | haproxy.router.openshift.io/timeout=3s |
    Then the step should succeed
    Given I have a test-client-pod in the project
    When I execute on the pod:
      | curl                                                                            |
      | https://<%= route("pass-route", service("pass-route")).dns(by: user) %>/delay/2 |
      | -k                                                                              |
    Then the step should succeed
    Then the output should contain:
      | "Host": "pass-route |
      | delay/2             |

    Given I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl                                                                            |
      | -Iv                                                                             |
      | https://<%= route("pass-route", service("pass-route")).dns(by: user) %>/delay/5 |
      | -k                                                                              |
    Then the step should fail
    And the output should contain "Empty reply from server"
    """

