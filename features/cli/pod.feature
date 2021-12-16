Feature: pods related scenarios

  # @author chezhang@redhat.com
  # @case_id OCP-11218
  @inactive
  Scenario: kubectl describe pod should show qos tier info when pod without limits and request info
    Given I have a project
    Given I obtain test data file "pods/hello-pod.json"
    When I run the :create client command with:
      | f | hello-pod.json |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I run the :describe client command with:
      | resource | pods            |
      | name     | hello-openshift |
    Then the output should match:
      | Status:\\s+Running    |
      | BestEffort            |
      | State:\\s+Running     |

  # @author chezhang@redhat.com
  # @case_id OCP-11527
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  Scenario: kubectl describe pod should show qos tier info
    Given I have a project
    Given I obtain test data file "quota/pod-notbesteffort.yaml"
    When I run the :create client command with:
      | f | pod-notbesteffort.yaml |
    Then the step should succeed
    Given I obtain test data file "pods/hello-pod-bad.json"
    When I run the :create client command with:
      | f | hello-pod-bad.json |
    Then the step should succeed
    Given the pod named "pod-notbesteffort" becomes ready
    When I run the :describe client command with:
      | resource | pods              |
      | name     | pod-notbesteffort |
    Then the output should match:
      | Status:\\s+Running |
      | Burstable          |
      | Limits:            |
      | cpu:\\s+500m       |
      | memory:\\s+256Mi   |
      | Requests:          |
      | cpu:\\s+200m       |
      | memory:\\s+256Mi   |
      | State:\\s+Running  |
    When I run the :describe client command with:
      | resource | pods              |
      | name     | hello-openshift   |
    Then the output should match:
      | Status:\\s+Pending |
      | BestEffort         |
      | State:\\s+Waiting  |

  # @author chezhang@redhat.com
  # @case_id OCP-10729
  @inactive
  Scenario: Implement supplemental groups for pod
    Given I have a project
    Given I obtain test data file "pods/ocp10729/pod-supplementalGroups.yaml"
    When I run the :create client command with:
      | f | pod-supplementalGroups.yaml |
    Then the step should succeed
    Given the pod named "hello-openshift" becomes ready
    When I run the :exec client command with:
      | pod          | hello-openshift |
      | exec_command | id              |
    Then the step should succeed
    And the output should contain:
      | groups=1234,5678, |
    Given I ensure "hello-openshift" pod is deleted
    Given I obtain test data file "pods/ocp10729/pod-supplementalGroups-multi-cotainers.yaml"
    When I run the :create client command with:
      | f | pod-supplementalGroups-multi-cotainers.yaml |
    Then the step should succeed
    Given the pod named "multi-containers" becomes ready
    When I run the :rsh client command with:
      | c        | hello-openshift     |
      | pod      | multi-containers    |
      | command  | id                  |
      | _timeout | 20                  |
    Then the step should succeed
    And the output should contain:
      | groups=1234,5678, |
    When I run the :rsh client command with:
      | c        | nfs-server          |
      | pod      | multi-containers    |
      | command  | id                  |
      | _timeout | 20                  |
    Then the step should succeed
    And the output should contain:
      | groups=1234,5678, |
    Given I ensure "multi-containers" pod is deleted
    Given I obtain test data file "pods/ocp10729/pod-supplementalGroups-invalid.yaml"
    When I run the :create client command with:
      | f | pod-supplementalGroups-invalid.yaml |
    Then the step should fail
    And the output should contain 2 times:
      | nvalid value |

  # @author chezhang@redhat.com
  # @case_id OCP-11753
  @4.10 @4.9
  Scenario: Pod should be immediately deleted if it's not scheduled even if graceful termination period is set
    Given I have a project
    Given I obtain test data file "pods/graceful-delete/10.json"
    When I run the :create client command with:
      | f | 10.json |
    Then the step should succeed
    Given the pod named "grace10" becomes ready
    When I run the :delete background client command with:
      | object_type       | pods    |
      | object_name_or_id | grace10 |
    Then the step should succeed
    Given the pod named "grace10" becomes terminating
    Then I wait for the resource "pod" named "grace10" to disappear within 30 seconds

  # @author cryan@redhat.com
  # @case_id OCP-10813
  # @bug_id 1324396
  @inactive
  Scenario: Update ActiveDeadlineSeconds for pod
    Given I have a project
    Given I obtain test data file "pods/ocp10813/hello-pod.json"
    When I run the :create client command with:
      | f | hello-pod.json |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | pod                                    |
      | resource_name | hello-openshift                        |
      | p             | {"spec":{"activeDeadlineSeconds":101}} |
    Then the step should fail
    And the output should contain "must be less than or equal to previous value"
    When I run the :patch client command with:
      | resource      | pod                                    |
      | resource_name | hello-openshift                        |
      | p             | {"spec":{"activeDeadlineSeconds":0}}   |
    Then the step should fail
    And the output should contain "Invalid value: 0"
    When I run the :patch client command with:
      | resource      | pod                                    |
      | resource_name | hello-openshift                        |
      | p             | {"spec":{"activeDeadlineSeconds":5.5}} |
    Then the step should fail
    And the output should match "(fractional integer|cannot convert float64 to int64)"
    When I run the :patch client command with:
      | resource      | pod                                    |
      | resource_name | hello-openshift                        |
      | p             | {"spec":{"activeDeadlineSeconds":-5}}  |
    Then the step should fail
    And the output should contain "Invalid value: -5"

  # @author qwang@redhat.com
  # @case_id OCP-11055
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  Scenario: /dev/shm can be automatically shared among all of a pod's containers
    Given I have a project
    Given I obtain test data file "pods/pod_with_two_containers.json"
    When I run the :create client command with:
      | f | pod_with_two_containers.json |
    Then the step should succeed
    And the pod named "doublecontainers" becomes ready
    # Enter container 1 and write files
    When I run the :exec client command with:
      | pod              | doublecontainers        |
      | container        | hello-openshift         |
      | oc_opts_end      |                         |
      | exec_command     | sh                      |
      | exec_command_arg | -c                      |
      | exec_command_arg | echo "hi" > /dev/shm/c1 |
    Then the step should succeed
    When I run the :exec client command with:
      | pod              | doublecontainers |
      | container        | hello-openshift  |
      | exec_command     | cat              |
      | exec_command_arg | /dev/shm/c1      |
    Then the step should succeed
    And the output should contain "hi"
    # Enter container 2 and check whether it can share the files under directory /dev/shm
    When I run the :exec client command with:
      | pod              | doublecontainers       |
      | container        | hello-openshift-fedora |
      | exec_command     | cat                    |
      | exec_command_arg | /dev/shm/c1            |
    Then the step should succeed
    And the output should contain "hi"
    # Write files in container 2 and check container 1
    When I run the :exec client command with:
      | pod              | doublecontainers           |
      | container        | hello-openshift-fedora     |
      | oc_opts_end      |                            |
      | exec_command     | sh                         |
      | exec_command_arg | -c                         |
      | exec_command_arg | echo "hello" > /dev/shm/c2 |
    Then the step should succeed
    When I run the :exec client command with:
      | pod              | doublecontainers |
      | container        | hello-openshift  |
      | exec_command     | cat              |
      | exec_command_arg | /dev/shm/c2      |
    Then the step should succeed
    And the output should contain "hello"

  # @author chuyu@redhat.com
  # @case_id OCP-22283
  @proxy
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  Scenario: 4.0 Oauth provider info should be consumed in a pod
    Given I have a project
    When I run the :new_app client command with:
      | docker_image | aosqe/ruby-ex |
      | l            | app=ruby-ex   |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | app=ruby-ex |
    When I run the :rsh client command with:
      | pod    | <%= pod.name %>                                                               |
      | _stdin | curl https://kubernetes.default.svc/.well-known/oauth-authorization-server -k |
    Then the step should succeed
    And the output should contain:
      | implicit           |
      | user:list-projects |

