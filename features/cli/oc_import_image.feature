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
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
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

  # @author geliu@redhat.com
  # @case_id OCP-12765
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-12765:ImageRegistry Allow imagestream request deployment config triggers by different mode('TagreferencePolicy':source/local)
    Given I have a project
    When I run the :tag client command with:
      | source_type | docker                                                |
      | source      | quay.io/openshifttest/deployment-example:v1-1.2.0 |
      | dest        | deployment-example:latest                             |
    Then the step should succeed
    And the "deployment-example" image stream becomes ready
    When I run the :new_app_as_dc client command with:
      | image_stream | deployment-example:latest   |
    Then the output should match:
      | .*[Ss]uccess.*|
    And a pod becomes ready with labels:
      | deploymentconfig=deployment-example |
    When I run the :get client command with:
      | resource        | imagestreams |
    Then the output should match:
      | .*deployment-example.* |
    When I run the :get client command with:
      | resource_name   | deployment-example |
      | resource        | dc                 |
      | o               | yaml               |
    Then the output should match:
      | deployment-example@sha256 |
    When I run the :delete client command with:
      | object_type | dc |
      | all         |    |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | is |
      | all         |    |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | svc |
      | all         |     |
    Then the step should succeed
    When I run the :tag client command with:
      | source_type      | docker                                                |
      | source           | quay.io/openshifttest/deployment-example:v1-1.2.0 |
      | dest             | deployment-example:latest                             |
      | reference_policy | local                                                 |
    Then the step should succeed
    And the "deployment-example" image stream becomes ready
    When I run the :new_app_as_dc client command with:
      | image_stream | deployment-example:latest   |
    Then the output should match:
      | .*[Ss]uccess.* |
    And a pod becomes ready with labels:
      | deploymentconfig=deployment-example |
    When I run the :get client command with:
      | resource        | imagestreams |
    Then the output should match:
      | .*deployment-example.* |
    When I run the :get client command with:
      | resource_name   | deployment-example |
      | resource        | dc                 |
      | o               | yaml               |
    Then the output should match:
      | <%= project.name %>\/deployment-example@sha256 |
