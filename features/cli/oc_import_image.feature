Feature: oc import-image related feature

  # @author wjiang@redhat.com
  # @case_id OCP-11760
  @inactive
  Scenario: OCP-11760:ImageRegistry Import Image when spec.DockerImageRepository not defined
    Given I have a project
    Given I obtain test data file "image-streams/ocp11760.json"
    When I run the :create client command with:
      | filename | ocp11760.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should contain:
      | aosqeruby:3.3 |
    And the output should not contain:
      | aosqeruby:latest |
    """

  # @author wjiang@redhat.com
  # @case_id OCP-12052
  @smoke
  @inactive
  Scenario: OCP-12052:ImageRegistry Import image when spec.DockerImageRepository with some tags defined when Kind==DockerImage
    Given I have a project
    Given I obtain test data file "image-streams/ocp12052.json"
    When I run the :create client command with:
      | filename | ocp12052.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should contain:
      | aosqeruby:3.3 |
    """

  # @author xiaocwan@redhat.com
  # @case_id OCP-11089
  @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  @inactive
  Scenario: OCP-11089:ImageRegistry Tags should be added to ImageStream if image repository is from an external docker registry
    Given I have a project
    Given I obtain test data file "image-streams/external.json"
    When I run the :create client command with:
      | f | external.json |
    Then the step should succeed
    And I wait for the steps to pass:
    ## istag will not show promtly as soon as is create, need wait for a few seconds
    """
    When I run the :get client command with:
      | resource | imageStreams |
      | o        | yaml         |
    Then the step should succeed
    And the output should match:
      | tag:\\s+None    |
      | tag:\\s+latest  |
      | tag:\\s+busybox |
    """
