Feature: set deployment-hook/build-hook with CLI

  # @author dyan@redhat.com
  # @case_id OCP-11805
  @proxy
  @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-11805:Workloads Set pre/mid/post deployment hooks on deployment config via oc set deployment-hook
    Given I have a project
    When I run the :create_deploymentconfig client command with:
      | image | quay.io/openshifttest/hello-openshift:1.2.0 |
      | name  | hello-openshift                                 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deploymentconfig=hello-openshift |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/hello-openshift  |
      | pre              |                     |
      | c                | default-container   |
      | e                | FOO1=BAR1           |
      | failure_policy   | retry               |
      | oc_opts_end      |                     |
      | args             | /bin/bash           |
      | args             | -c                  |
      | args             | /bin/sleep 5        |
    Then the step should succeed
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/hello-openshift |
      | post             |                    |
      | oc_opts_end      |                    |
      | args             | /bin/true          |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | hello-openshift |
    Then the step should succeed
    And the output should match:
      | [Pp]re-deployment hook    |
      | failure policy: [Rr]etry  |
      | /bin/bash -c /bin/sleep 5 |
      | FOO1=BAR1                 |
      | [Pp]ost-deployment hook   |
      | failure policy: [Ii]gnore |
      | /bin/true                 |
    Given I wait until the status of deployment "hello-openshift" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | dc/hello-openshift |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=hello-openshift-2 |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/hello-openshift  |
      | pre              |                     |
      | c                | default-container   |
      | failure_policy   | retry               |
      | oc_opts_end      |                     |
      | args             | /bin/bash           |
      | args             | -c                  |
      | args             | /bin/sleep 10       |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | hello-openshift |
    Then the step should succeed
    And the output should match:
      | [Pp]re-deployment hook    |
      | failure policy: [Rr]etry  |
      | /bin/bash -c /bin/sleep 10|
      | [Pp]ost-deployment hook   |
      | failure policy: [Ii]gnore |
      | /bin/true                 |
    Given I wait until the status of deployment "hello-openshift" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | dc/hello-openshift |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=hello-openshift-3 |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/hello-openshift |
      | remove           |                    |
      | pre              |                    |
      | post             |                    |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | hello-openshift |
    Then the step should succeed
    And the output should not match:
      | [Pp]re-deployment hook  |
      | [Pp]ost-deployment hook |

  # @author dyan@redhat.com
  # @case_id OCP-11298
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @inactive
  @critical
  Scenario: OCP-11298:BuildAPI Set invalid pre/mid/post deployment hooks on deployment config via oc set deployment-hook
    Given I have a project
    When I run the :new_app client command with:
      | template | rails-postgresql-example |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=rails-postgresql-example-1 |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/rails-postgresql-example |
      | post             |                             |
      | o                | json                        |
      | oc_opts_end      |                             |
      | args             | /bin/true                   |
    Then the step should succeed
    When I save the output to file> dc.json
    And I run the :set_deployment_hook client command with:
      | mid            |            |
      | f              | dc.json    |
      | failure_policy | abort      |
      | oc_opts_end    |            |
      | args           | /bin/false |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | rails-postgresql-example |
    Then the step should succeed
    And the output should match:
      | [Mm]id-deployment hook   |
      | failure policy: [Aa]bort |
      | /bin/false               |
    Given I wait until the status of deployment "rails-postgresql-example" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | dc/rails-postgresql-example |
    Then the step should succeed
    And I wait until the status of deployment "rails-postgresql-example" becomes :failed

