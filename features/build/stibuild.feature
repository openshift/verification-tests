Feature: stibuild.feature

  # @author xiuwang@redhat.com
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Trigger s2i/docker/custom build using additional imagestream
    Given I have a project
    Given I obtain test data file "templates/<template>"
    And I run the :new_app client command with:
      | file | <template> |
    Then the step should succeed
    And the "sample-build-1" build was created
    When I run the :cancel_build client command with:
      | build_name | sample-build-1                  |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | myimage                                       |
      | from       | registry.redhat.io/rhscl/ruby-27-rhel7:latest |
      | confirm    | true                                          |
    Then the step should succeed
    And the "sample-build-2" build was created
    When I run the :describe client command with:
      | resource | builds         |
      | name     | sample-build-2 |
    Then the step should succeed
    And the output should contain:
      |Build trigger cause:	Image change                           |
      |Image ID:		registry.redhat.io/rhscl/ruby-27-rhel7 |
      |Image Name/Kind:	myimage:latest                                 |
    When I run the :start_build client command with:
      | buildconfig | sample-build |
    Then the step should succeed
    And the "sample-build-3" build was created
    When I get project builds
    Then the step should succeed
    And the output should not contain "sample-build-4"

    @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
    @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
    @upgrade-sanity
    @singlenode
    @proxy @noproxy @connected
    @network-ovnkubernetes @network-openshiftsdn
    @heterogeneous @arm64 @amd64
    @inactive
    Examples:
      | case_id            | template          |
      | OCP-12041:BuildAPI | ocp12041-s2i.json | # @case_id OCP-12041

  # @author wzheng@redhat.com
  # @case_id OCP-30858
  @proxy
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-30858:BuildAPI STI build with dockerImage with specified tag
    Given I have a project
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/ruby-27:multiarch   |
      | app_repo     | https://github.com/sclorg/ruby-ex   |
    Then the step should succeed
    And the "ruby-ex-1" build completes
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                      |
      | resource_name | ruby-ex                                                                                                                                          |
      | p             | {"spec": {"strategy": {"sourceStrategy": {"from": {"kind": "DockerImage","name": "quay.io/openshifttest/ruby-27@sha256:cdb6a13032184468b1e0607f36cfb8834c97dbeffeeff800e9e6834323bed8fc"}}},"type": "Source"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-ex |
    Then the step should succeed
    And the "ruby-ex-2" build completes
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | buildconfig                                                                                                                                     |
      | resource_name | ruby-ex                                                                                                                                         |
      | p             | {"spec": {"strategy": {"sourceStrategy": {"from": {"kind": "DockerImage","name": "quay.io/openshifttest/ruby-25-centos7:error"}}},"type": "Source"}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-ex |
    Then the step should succeed
    And the "ruby-ex-3" build failed
    When I run the :describe client command with:
      | resource | build     |
      | name     | ruby-ex-3 |
    Then the step should succeed
    And the output should contain "error"

  # @author wzheng@redhat.com
  # @case_id OCP-22596
  @proxy
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-22596:ImageRegistry Create app with template eap73-basic-s2i with jbosseap rhel7 image
    Given I have a project
    When I run the :new_app client command with:
      | template | eap73-basic-s2i |
    Then the step should succeed
    Given the "eap-app-build-artifacts-1" build was created
    And the "eap-app-build-artifacts-1" build completed
    Given 1 pod becomes ready with labels:
      | openshift.io/build.name=eap-app-build-artifacts-1 |
    Given the "eap-app-2" build was created
    And the "eap-app-2" build completed
    Given 1 pod becomes ready with labels:
      | application=eap-app |

  # @author xiuwang@redhat.com
  # @case_id OCP-28891
  @noproxy @disconnected
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-28891:BuildAPI Test s2i build in disconnect cluster
    Given I have a project
    When I have an http-git service in the project
    And I run the :set_env client command with:
      | resource | dc/git               |
      | e        | REQUIRE_SERVER_AUTH= |
      | e        | REQUIRE_GIT_AUTH=    |
    Then the step should succeed
    When a pod becomes ready with labels:
      | deploymentconfig=git |
      | deployment=git-2     |
    Given I obtain test data dir "build/httpd-ex.git"
    When I run the :cp client command with:
      | source | httpd-ex.git |
      | dest   | <%= pod.name %>:/var/lib/git/                       |
    Then the step should succeed
    When I run the :new_app client command with:
      | app_repo | openshift/httpd:latest~http://<%= cb.git_route %>/httpd-ex.git |
    Then the step should succeed
    Given the "httpd-ex-1" build was created
    And the "httpd-ex-1" build completes

  # @author xiuwang@redhat.com
  # @case_id OCP-42159
  @flaky
  @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  Scenario: OCP-42159:BuildAPI Mount source secret and configmap to builder container- sourcestrategy
    Given I have a project
    When I run the :create_secret client command with:
      | secret_type  | generic            |
      | name         | mysecret           |
      | from_literal | username=openshift |
      | from_literal | password=redhat    |
    Then the step should succeed
    When I run the :create_configmap client command with:
      | name         | myconfig  |
      | from_literal | key=foo   |
      | from_literal | value=bar |
    Then the step should succeed
    When I run the :new_app client command with:
      | image_stream | ruby                                             |
      | app_repo     | http://github.com/openshift/ruby-hello-world.git |
    Then the step should succeed
    And the "ruby-hello-world-1" build was created
    Given the "ruby-hello-world-1" build completed
    When I run the :patch client command with:
      | resource      | buildconfig      |
      | resource_name | ruby-hello-world |
      | p             | {"spec":{"strategy":{"sourceStrategy":{"volumes":[{"mounts":[{"destinationPath":"/var/run/secret/mysecret"}],"name":"mysecret","source":{"secret":{"secretName":"mysecret"},"type":"Secret"}},{"mounts":[{"destinationPath":"/var/run/secret/myconfig"}],"name":"myconfig","source":{"configMap":{"name":"myconfig"},"type":"ConfigMap"}}]}}}} |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And the "ruby-hello-world-2" build was created
    Given the "ruby-hello-world-2" build completed
    When I run the :get client command with:
      | resource      | pod                      |
      | resource_name | ruby-hello-world-2-build |
      | o             | yaml                     |
    Then the output should contain:
      | mysecret-user-build-volume |
      | myconfig-user-build-volume |
