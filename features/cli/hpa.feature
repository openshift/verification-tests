Feature: hpa scale

  # @author chezhang@redhat.com
  # @case_id OCP-10931
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-10931 HPA shouldn't scale up target if the replicas of dc is 0
    Given I have a project
    Given I obtain test data file "hpa/dc-hello-openshift.yaml"
    When I run the :create client command with:
      | f | dc-hello-openshift.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=hello-openshift-1 |
    When I run the :autoscale client command with:
      | name | dc/hello-openshift    |
      | min  | 2                     |
      | max  | 10                    |
    Then the step should succeed
    When I get project hpa
    Then the output should match:
      | hello-openshift.*80%.*2\\s+10 |
    And I wait until number of replicas match "2" for replicationController "hello-openshift-1"
    Given 2 pods become ready with labels:
      | deployment=hello-openshift-1 |
    When I run the :scale client command with:
      | resource | deploymentconfig  |
      | name     | hello-openshift   |
      | replicas | 0                 |
    Then the step should succeed
    And I wait until number of replicas match "0" for replicationController "hello-openshift-1"
    Given 35 seconds have passed
    And I wait until number of replicas match "0" for replicationController "hello-openshift-1"
    Given all existing pods die with labels:
      | deployment=hello-openshift-1 |
    When I get project pods
    Then the step should succeed
    And the output should not match:
      | hello-openshift-1.*Running |

  # @author chezhang@redhat.com
  # @case_id OCP-11338
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-11338 HPA shouldn't scale up target if the replicas of rc is 0
    Given I have a project
    Given I obtain test data file "hpa/rc-hello-openshift.yaml"
    When I run the :create client command with:
      | f | rc-hello-openshift.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-openshift" is ready
    When I run the :autoscale client command with:
      | name | rc/hello-openshift |
      | min  | 2                  |
      | max  | 10                 |
    Then the step should succeed
    When I get project hpa
    Then the output should match:
      | hello-openshift.*80%.*2\\s+10     |
    And I wait until number of replicas match "2" for replicationController "hello-openshift"
    Given 2 pods become ready with labels:
      | run=hello-openshift               |
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | hello-openshift        |
      | replicas | 0                      |
    Then the step should succeed
    And I wait until number of replicas match "0" for replicationController "hello-openshift"
    Given 35 seconds have passed
    And I wait until number of replicas match "0" for replicationController "hello-openshift"
    Given all existing pods die with labels:
      | run=hello-openshift |
    When I get project pods
    Then the step should succeed
    And the output should not contain "hello-openshift-"

  # @author chezhang@redhat.com
  # @case_id OCP-11259
  @smoke
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: OCP-11259 Creates autoscaler for replication controller by oc autoscale
    Given I have a project
    Given I obtain test data file "hpa/rc-hello-openshift.yaml"
    When I run the :create client command with:
      | f | rc-hello-openshift.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-openshift" is ready
    When I run the :autoscale client command with:
      | name | rc/hello-openshift |
      | min  | 2                  |
      | max  | 10                 |
    Then the step should succeed
    When I get project hpa
    Then the output should match:
      | hello-openshift.*80%.*2\\s+10 |
    And I wait until number of replicas match "2" for replicationController "hello-openshift"
    When I run the :delete client command with:
      | object_type       | hpa             |
      | object_name_or_id | hello-openshift |
    Then the step should succeed
    When I run the :autoscale client command with:
      | name        | rc/hello-openshift |
      | max         | 5                  |
      | cpu-percent | 30                 |
    Then the step should succeed
    When I get project hpa
    Then the output should match:
      | hello-openshift.*30%.*1\\s+5  |
    And a pod becomes ready with labels:
      | run=hello-openshift           |
    When I run the :delete client command with:
      | object_type       | hpa             |
      | object_name_or_id | hello-openshift |
    Then the step should succeed
    When I run the :autoscale client command with:
      | name        | rc/hello-openshift |
      | min         | -1                 |
      | max         | 5                  |
      | cpu-percent | -1                 |
    Then the step should succeed
    When I get project hpa
    Then the output should match:
      | hello-openshift.*80%.*1\\s+5  |
    And a pod becomes ready with labels:
      | run=hello-openshift           |

  # @author chezhang@redhat.com
  # @case_id OCP-11576
  Scenario: OCP-11576 Creates autoscaler for replication controller with invalid value
    Given I have a project
    Given I obtain test data file "hpa/rc-hello-openshift.yaml"
    When I run the :create client command with:
      | f | rc-hello-openshift.yaml |
    Then the step should succeed
    Given I wait until replicationController "hello-openshift" is ready
    When I run the :autoscale client command with:
      | name | rc/hello-openshift |
      | min  | 15                 |
      | max  | 10                 |
    Then the step should fail
    And the output should match:
      | MAXPODS must be larger or equal to.*MINPODS |
    When I run the :autoscale client command with:
      | name | rc/hello-openshift |
      | max  | 0                  |
      | max  | 0                  |
     Then the step should fail
    And the output should match:
      | MAXPODS is required and must be at least 1 |
    When I run the :autoscale client command with:
      | name | rc/hello-openshift |
      | min  | -2                 |
      | max  | -5                 |
     Then the step should fail
    And the output should match:
      | MAXPODS is required and must be at least 1 |

