Feature: build related upgrade check

  # @author wewang@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @proxy
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  Scenario: Check docker and sti build works well before and after upgrade - prepare
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | build-upgrade |
    Then the step should succeed
    When I run the :new_app_as_dc client command with:
      | app_repo | openshift/ruby~https://github.com/openshift/ruby-ex |
    Then the step should succeed
    When I run the :new_app_as_dc client command with:
      | app_repo | quay.io/openshifttest/ruby-27:1.2.0~https://github.com/openshift/ruby-hello-world |
      | strategy | docker                                                                                |
    Then the step should succeed
    Given I use the "build-upgrade" project
    Then the "ruby-ex-1" build completed
    And the "ruby-hello-world-1" build completed

  # @author wewang@redhat.com
  # @case_id OCP-13025
  @upgrade-check
  @users=upuser1,upuser2
  @proxy
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @inactive
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  Scenario: Check docker and sti build works well before and after upgrade
    Given I switch to the first user
    When I use the "build-upgrade" project
    And status becomes :running of 1 pods labeled:
      | deployment=ruby-ex-1 |
    And status becomes :running of 1 pods labeled:
      | deployment=ruby-hello-world-1 |
    When I run the :start_build client command with:
      | buildconfig | ruby-ex |
    Then the step should succeed
    And status becomes :running of 1 pods labeled:
      | deployment=ruby-ex-2 |
    When I run the :start_build client command with:
      | buildconfig | ruby-hello-world |
    Then the step should succeed
    And status becomes :running of 1 pods labeled:
      | deployment=ruby-hello-world-2 |
