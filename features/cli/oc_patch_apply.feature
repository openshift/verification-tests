Feature: oc patch/apply related scenarios

  # @author xxia@redhat.com
  # @case_id OCP-10696
  @smoke
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10696:Workloads oc patch can update one or more fields of rescource
    Given I have a project
    And I run the :create_deploymentconfig client command with:
      | name  | hello                                               |
      | image | quay.io/openshifttest/hello-openshift@sha256:b6296396b632d15daf9b5e62cf26da20d76157161035fefddbd0e7f7749f4167 |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | hello           |
      | p             | {"spec":{"replicas":2}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | hello              |
      | template      | {{.spec.replicas}} |
    Then the step should succeed
    And the output should contain "2"
    """
    When I run the :patch client command with:
      | resource      | dc              |
      | resource_name | hello           |
      | p             | {"metadata":{"labels":{"template":"newtemp","name1":"value1"}},"spec":{"replicas":3}} |
    Then the step should succeed
    Then I wait for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | dc                 |
      | resource_name | hello              |
      | template      | {{.metadata.labels.template}} {{.metadata.labels.name1}} {{.spec.replicas}} |
    Then the step should succeed
    And the output should contain "newtemp value1 3"
    """
