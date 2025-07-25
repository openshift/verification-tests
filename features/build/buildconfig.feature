Feature: buildconfig.feature

  # @author wzheng@redhat.com
  # @case_id OCP-12121
  @inactive
  Scenario: OCP-12121:ImageRegistry Start build from buildConfig/build
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/ruby:latest |
      | app_repo     | https://github.com/openshift/ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    And the "ruby-hello-world-1" build finished
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build was created
    And the "ruby-hello-world-2" build completed
    When I run the :start_build client command with:
      | from_build | ruby-hello-world-2 |
    Then the step should succeed
    And the "ruby-hello-world-3" build was created
    And the "ruby-hello-world-3" build completed

  # @author haowang@redhat.com
  # @case_id OCP-10667
  @inactive
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  Scenario: OCP-10667:BuildAPI Rebuild image when the underlying image changed for Docker build
    Given I have a project
    When I run the :new_build client command with:
      | D    | FROM quay.io/openshifttest/base-alpine@sha256:3126e4eed4a3ebd8bf972b2453fa838200988ee07c01b2251e3ea47e4b1f245c\nRUN echo "hello" |
      | to   | centos  |
      | name | mybuild |
    Then the step should succeed
    Then the "centos" image stream was created
    And the "mybuild-1" build was created
    When I run the :tag client command with:
      | source_type | docker         |
      | source      | openshift/ruby |
      | dest        | centos:latest  |
    Then the step should succeed
    And the "mybuild-2" build was created

  # @author dyan@redhat.com
  # @case_id OCP-12020
  @inactive
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  Scenario: OCP-12020:BuildAPI Trigger chain builds from a image update
    Given I have a project
    When I run the :new_build client command with:
      | app_repo     | registry.redhat.io/rhscl/ruby-27-rhel7:latest~https://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    Then the "ruby-27-rhel7" image stream was created
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build becomes :complete
    When I run the :new_build client command with:
      | image_stream | ruby-hello-world                  |
      | code         | https://github.com/sclorg/ruby-ex |
      | name         | ruby-ex                           |
    Then the step should succeed
    And the "ruby-ex-1" build was created
    When I run the :tag client command with:
      | source_type      | docker                |
      | source           | openshift/ruby:latest |
      | dest             | ruby-27-rhel7:latest  |
      | reference_policy | local                  |
    Then the step should succeed
    And the "ruby-hello-world-2" build was created
    When the "ruby-hello-world-2" build becomes :complete
    Then the "ruby-ex-2" build was created

  # @author haowang@redhat.com
  @proxy
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Build with images pulled from private repositories
    Given I have a project
    When I run the :create_secret client command with:
     | name        | pull                                                                            |
     | secret_type | generic                                                                         |
     | from_file   | .dockercfg=<%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %> |
     | type        | kubernetes.io/dockercfg                                                         |
    Then the step should succeed
    Given I obtain test data file "build/ocp11474/<template>"
    When I run the :create client command with:
      | f | <template> |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    Then the "ruby-sample-build-1" build completes

    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @singlenode
    @noproxy @connected
    @network-ovnkubernetes @other-cni @network-openshiftsdn
    @s390x @ppc64le @heterogeneous @arm64 @amd64
    @inactive
    Examples:
      | case_id            | template                  |
      | OCP-11474:BuildAPI | test-buildconfig-s2i.json | # @case_id OCP-11474

  # @author xiuwang@redhat.com
  # @case_id OCP-12057
  @proxy
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @other-cni @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @inactive
  @critical
  Scenario: OCP-12057:BuildAPI Using secret to pull a docker image which be used as source input
    Given I have a project
    When I run the :create_secret client command with:
     | name        | pull                                                                            |
     | secret_type | generic                                                                         |
     | from_file   | .dockercfg=<%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %> |
     | type        | kubernetes.io/dockercfg                                                         |
    Then the step should succeed
    Given I obtain test data file "templates/OCP-12057/application-template-stibuild_pull_private_sourceimage.json"
    When I run the :new_app client command with:
     | file | application-template-stibuild_pull_private_sourceimage.json |
    Then the step should succeed
    And the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    Given a pod becomes ready with labels:
     | name=frontend |
    When I execute on the pod:
     | ls | openshiftqedir |
    Then the step should succeed
    And the output should contain:
     | app-root |
