Feature: deployment related steps

  # @author chezhang@redhat.com
  # @case_id OCP-11421
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @critical
  @hypershift-hosted
  Scenario: OCP-11421:Workloads Add perma-failed - Deplyment succeed after change pod template by edit deployment
    Given I have a project
    Given I obtain test data file "deployment/deployment-perme-failed-1.yaml"
    When I run the :create client command with:
      | f | deployment-perme-failed-1.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+True\\s+ReplicaSetUpdated         |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability  |
      | MinimumReplicasUnavailable                     |
      | status: "False"                                |
      | type: Available                                |
      | "hello-openshift.*" is progressing             |
      | ReplicaSetUpdated                              |
      | status: "True"                                 |
      | type: Progressing                              |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource  | deployment |
      | o         | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability             |
      | MinimumReplicasUnavailable                                |
      | status: "False"                                           |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """
    When I run the :patch client command with:
      | resource      | deployment                                                                                                     |
      | resource_name | hello-openshift                                                                                                |
      | p             | {"spec":{"template":{"spec":{"containers":[{"name":"hello-openshift","image":"quay.io/openshifttest/hello-openshift@sha256:b6296396b632d15daf9b5e62cf26da20d76157161035fefddbd0e7f7749f4167"}]}}}} |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable |
      | Progressing\\s+True\\s+NewReplicaSetAvailable |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                         |
      | MinimumReplicasAvailable                                    |
      | status: "True"                                              |
      | type: Available                                             |
      | "hello-openshift.*" has successfully progressed             |
      | NewReplicaSetAvailable                                      |
      | status: "True"                                              |
      | type: Progressing                                           |
    """

  # @author chezhang@redhat.com
  # @case_id OCP-11046
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @critical
  @hypershift-hosted
  @network-ovnkubernetes @network-openshiftsdn
  Scenario: OCP-11046:Workloads Add perma-failed - Deployment failed after pausing and resuming
    Given I have a project
    Given I obtain test data file "deployment/deployment-perme-failed-1.yaml"
    When I run the :create client command with:
      | f | deployment-perme-failed-1.yaml |
    Then the step should succeed
    When I run the :rollout_pause client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+Unknown\\s+DeploymentPaused       |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability |
      | MinimumReplicasUnavailable                    |
      | status: "False"                               |
      | type: Available                               |
      | Deployment is paused                          |
      | DeploymentPaused                              |
      | status: Unknown                               |
      | type: Progressing                             |
    Given 60 seconds have passed
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+Unknown\\s+DeploymentPaused       |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability |
      | MinimumReplicasUnavailable                    |
      | status: "False"                               |
      | type: Available                               |
      | Deployment is paused                          |
      | DeploymentPaused                              |
      | status: Unknown                               |
      | type: Progressing                             |
    When I run the :rollout_resume client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+Unknown\\s+DeploymentResumed      |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability |
      | MinimumReplicasUnavailable                    |
      | status: "False"                               |
      | type: Available                               |
      | Deployment is resumed                         |
      | DeploymentResumed                             |
      | status: Unknown                               |
      | type: Progressing                             |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource  | deployment |
      | o         | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability             |
      | MinimumReplicasUnavailable                                |
      | status: "False"                                           |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """

  # @author chezhang@redhat.com
  # @case_id OCP-11681
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @critical
  @hypershift-hosted
  Scenario: OCP-11681:Workloads Add perma-failed - Failing deployment can be rolled back successful
    Given I have a project
    Given I obtain test data file "deployment/deployment-perme-failed-3.yaml"
    When I run the :create client command with:
      | f | deployment-perme-failed-3.yaml |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable |
      | Progressing\\s+True\\s+NewReplicaSetAvailable |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                         |
      | MinimumReplicasAvailable                                    |
      | status: "True"                                              |
      | type: Available                                             |
      | "hello-openshift.*" has successfully progressed             |
      | NewReplicaSetAvailable                                      |
      | status: "True"                                              |
      | type: Progressing                                           |
    """
    When I run the :patch client command with:
      | resource      | deployment                                                                                                     |
      | resource_name | hello-openshift                                                                                                |
      | p             | {"spec":{"template":{"spec":{"containers":[{"name":"hello-openshift","image":"quay.io/openshifttest/nonexist"}]}}}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable |
      | Progressing\\s+True\\s+ReplicaSetUpdated      |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability            |
      | MinimumReplicasAvailable                       |
      | status: "True"                                 |
      | type: Available                                |
      | "hello-openshift.*" is progressing             |
      | ReplicaSetUpdated                              |
      | status: "True"                                 |
      | type: Progressing                              |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable    |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                       |
      | MinimumReplicasAvailable                                  |
      | status: "True"                                            |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """
    When I run the :rollout_undo client command with:
      | resource      | deployment      |
      | resource_name | hello-openshift |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable |
      | Progressing\\s+True\\s+NewReplicaSetAvailable |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                         |
      | MinimumReplicasAvailable                                    |
      | status: "True"                                              |
      | type: Available                                             |
      | "hello-openshift.*" has successfully progressed             |
      | NewReplicaSetAvailable                                      |
      | status: "True"                                              |
      | type: Progressing                                           |
    """

  # @author chezhang@redhat.com
  # @case_id OCP-12110
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @critical
  @hypershift-hosted
  Scenario: OCP-12110:Workloads Add perma-failed - Rolling back to a failing deployment revision
    Given I have a project
    Given I obtain test data file "deployment/deployment-perme-failed-3.yaml"
    When I run the :create client command with:
      | f | deployment-perme-failed-3.yaml |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable |
      | Progressing\\s+True\\s+NewReplicaSetAvailable |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                         |
      | MinimumReplicasAvailable                                    |
      | status: "True"                                              |
      | type: Available                                             |
      | "hello-openshift.*" has successfully progressed             |
      | NewReplicaSetAvailable                                      |
      | status: "True"                                              |
      | type: Progressing                                           |
    """
    When I run the :patch client command with:
      | resource      | deployment                                                                                                               |
      | resource_name | hello-openshift                                                                                                          |
      | p             | {"spec":{"template":{"spec":{"containers":[{"name":"hello-openshift","image":"quay.io/openshifttest/nonexist-1"}]}}}} |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable    |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                       |
      | MinimumReplicasAvailable                                  |
      | status: "True"                                            |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """
    When I run the :patch client command with:
      | resource      | deployment                                                                                                               |
      | resource_name | hello-openshift                                                                                                          |
      | p             | {"spec":{"template":{"spec":{"containers":[{"name":"hello-openshift","image":"quay.io/openshifttest/nonexist-2"}]}}}} |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable    |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                       |
      | MinimumReplicasAvailable                                  |
      | status: "True"                                            |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """
    When I run the :rollout_undo client command with:
      | resource      | deployment      |
      | resource_name | hello-openshift |
    Then the step should succeed
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+True\\s+MinimumReplicasAvailable    |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource  | deployment |
      | o         | yaml       |
    Then the output by order should match:
      | Deployment has minimum availability                       |
      | MinimumReplicasAvailable                                  |
      | status: "True"                                            |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """

  # @author chezhang@redhat.com
  # @case_id OCP-11865
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @critical
  @hypershift-hosted
  Scenario: OCP-11865:Workloads Add perma-failed - Make a change outside pod template for failing deployment
    Given I have a project
    Given I obtain test data file "deployment/deployment-perme-failed-1.yaml"
    When I run the :create client command with:
      | f | deployment-perme-failed-1.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+True\\s+ReplicaSetUpdated         |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability  |
      | MinimumReplicasUnavailable                     |
      | status: "False"                                |
      | type: Available                                |
      | "hello-openshift.*" is progressing             |
      | ReplicaSetUpdated                              |
      | status: "True"                                 |
      | type: Progressing                              |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability             |
      | MinimumReplicasUnavailable                                |
      | status: "False"                                           |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """
    When I run the :patch client command with:
      | resource      | deployment                                                                                                     |
      | resource_name | hello-openshift                                                                                                |
      | p             | {"spec":{"replicas":3}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+True\\s+ReplicaSetUpdated         |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability  |
      | MinimumReplicasUnavailable                     |
      | status: "False"                                |
      | type: Available                                |
      | "hello-openshift.*" is progressing             |
      | ReplicaSetUpdated                              |
      | status: "True"                                 |
      | type: Progressing                              |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the output should match:
      | Available\\s+False\\s+MinimumReplicasUnavailable |
      | Progressing\\s+False\\s+ProgressDeadlineExceeded |
    When I run the :get client command with:
      | resource | deployment |
      | o        | yaml       |
    Then the output by order should match:
      | Deployment does not have minimum availability             |
      | MinimumReplicasUnavailable                                |
      | status: "False"                                           |
      | type: Available                                           |
      | "hello-openshift.*" has timed out progressing             |
      | ProgressDeadlineExceeded                                  |
      | status: "False"                                           |
      | type: Progressing                                         |
    """

  # @author chezhang@redhat.com
  # @case_id OCP-12009
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @proxy @noproxy @connected
  @critical
  @hypershift-hosted
  Scenario: OCP-12009:Workloads Add perma-failed - Negative value test of progressDeadlineSeconds in failing deployment
    Given I have a project
    Given I obtain test data file "deployment/deployment-perme-failed-2.yaml"
    When I run the :create client command with:
      | f | deployment-perme-failed-2.yaml |
    Then the step should fail
    And the output should match:
     | spec.progressDeadlineSeconds: Invalid value.*must be greater than minReadySeconds |
    When I replace lines in "deployment-perme-failed-2.yaml":
      | progressDeadlineSeconds: 0 | progressDeadlineSeconds: -1 |
    Then I run the :create client command with:
      | f | deployment-perme-failed-2.yaml |
    And the step should fail
    And the output should match:
      | spec.progressDeadlineSeconds: Invalid value.*must be greater than or equal to 0 |
      | spec.progressDeadlineSeconds: Invalid value.*must be greater than minReadySeconds |
    When I replace lines in "deployment-perme-failed-2.yaml":
      | progressDeadlineSeconds: -1 | progressDeadlineSeconds: ab |
    Then I run the :create client command with:
      | f | deployment-perme-failed-2.yaml |
    And the step should fail
    When I replace lines in "deployment-perme-failed-2.yaml":
      | progressDeadlineSeconds: ab | progressDeadlineSeconds: 0.5 |
    Then I run the :create client command with:
      | f | deployment-perme-failed-2.yaml |
    And the step should fail

