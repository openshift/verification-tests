Feature: job.feature

  # @author cryan@redhat.com
  # @case_id OCP-11206
  @4.10 @4.9
  @vsphere-ipi @gcp-ipi @aws-ipi
  @vsphere-upi @gcp-upi
  Scenario: Create job with multiple completions
    Given I have a project
    Given I obtain test data file "templates/ocp11206/job.yaml"
    When I run the :create client command with:
      | f | job.yaml |
    Then the step should succeed
    Given 5 pods become ready with labels:
      | app=pi |
    When I get project pods with labels:
      | app=pi |
    Then the step should succeed
    And the output should contain 5 times:
      |  pi- |
    Given 5 pods become ready with labels:
      | app=pi |
    Given evaluation of `@pods[0].name` is stored in the :pilog clipboard
    Given the pod named "<%= cb.pilog %>" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | <%= cb.pilog %> |
    Then the step should succeed
    And the output should contain "hello-openshift"
    When I run the :delete client command with:
      | object_type | job |
      | object_name_or_id | pi |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pods with labels:
      | app=pi |
    Then the step should succeed
    And the output should not contain "pi-"
    """
    Given I obtain test data file "templates/ocp11206/job.yaml"
    When I run oc create over "job.yaml" replacing paths:
      | ["spec"]["completions"] | -1 |
    Then the step should fail
    And the output should contain "must be greater than or equal to 0"
    Given I obtain test data file "templates/ocp11206/job.yaml"
    When I run oc create over "job.yaml" replacing paths:
      | ["spec"]["completions"] | 0.1 |
    Then the step should fail

  # @author qwang@redhat.com
  # @case_id OCP-11539
  @4.10 @4.9
  @vsphere-ipi @gcp-ipi @aws-ipi
  @vsphere-upi @gcp-upi
  Scenario: Create job with pod parallelism
    Given I have a project
    Given I obtain test data file "job/job_with_0_activeDeadlineSeconds.yaml"
    When I run oc create over "job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | 1    |
      | ["spec"]["completions"]           | null |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | app=pi |
    When I get project pods with labels:
      | app=pi |
    Then the output should contain 1 times:
      |  zero- |
    # Check job-pod log
    Given evaluation of `@pods[0].name` is stored in the :pilog clipboard
    Given the pod named "<%= cb.pilog %>" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | <%= cb.pilog %> |
    Then the step should succeed
    And the output should contain "hello-openshift"
    # Delete job and check job and pod
    When I run the :delete client command with:
      | object_type       | job  |
      | object_name_or_id | zero |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I store in the clipboard the pods labeled:
      | app=pi |
    Then the expression should be true> cb.pods.empty?
    """
    # Create a job with invalid completions valuse
    Given I obtain test data file "job/job_with_0_activeDeadlineSeconds.yaml"
    When I run oc create over "job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | -1   |
      | ["spec"]["completions"]           | null |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should fail
    And the output should contain:
      | spec.parallelism |
      | must be greater than or equal to 0 |
    Given I obtain test data file "job/job_with_0_activeDeadlineSeconds.yaml"
    When I run oc create over "job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | 0.1  |
      | ["spec"]["completions"]           | null |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should fail
    # Create a job with both "parallelism" < "completions"
    Given I obtain test data file "job/job_with_0_activeDeadlineSeconds.yaml"
    When I run oc create over "job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | 2    |
      | ["spec"]["completions"]           | 3    |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should succeed
    When I get project pods with labels:
      | app=pi |
    Then the output should contain 2 times:
      |  zero- |
    Given 3 pods become ready with labels:
      | app=pi |
    When I get project pods with labels:
      | app=pi |
    Then the output should contain 3 times:
      |  zero- |
    # Create a job with both "parallelism" > "completions"
    When I run the :delete client command with:
      | object_type       | job  |
      | object_name_or_id | zero |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I store in the clipboard the pods labeled:
      | app=pi |
    Then the expression should be true> cb.pods.empty?
    """
    Given I obtain test data file "job/job_with_0_activeDeadlineSeconds.yaml"
    When I run oc create over "job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | 3    |
      | ["spec"]["completions"]           | 2    |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should succeed
    When I get project pods with labels:
      | app=pi |
    Then the output should contain 2 times:
      |  zero- |
    Given 2 pods become ready with labels:
      | app=pi |
    When I get project pods with labels:
      | app=pi |
    Then the output should contain 2 times:
      |  zero- |

  # @author qwang@redhat.com
  # @case_id OCP-9948
  @inactive
  Scenario: Create job with activeDeadlineSeconds
    Given I have a project
    Given I obtain test data file "job/job_with_lessthan_runtime_activeDeadlineSeconds.yaml"
    When I run the :create client command with:
      | f | job_with_lessthan_runtime_activeDeadlineSeconds.yaml |
    Then the step should succeed
    When I get project job
    Then the output should match:
      | pi\\s+1\\s+0 |
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | job        |
      | name     | pi         |
    Then the output should contain:
      | DeadlineExceeded                              |
      | Job was active longer than specified deadline |
    """

  # @author qwang@redhat.com
  # @case_id OCP-9952
  @4.10 @4.9
  @vsphere-ipi @gcp-ipi @aws-ipi
  @vsphere-upi @gcp-upi
  Scenario: Specifying your own pod selector for job
    Given I have a project
    Given I obtain test data file "job/job-manualselector.yaml"
    When I run the :create client command with:
      | f | job-manualselector.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | job |
      | name     | pi  |
    Then the output should contain "controller-uid=64e92bd2-078d-11e6-a269-fa163e15bd57"
    Given I obtain test data file "job/job_with_0_activeDeadlineSeconds.yaml"
    When I run oc create over "job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["manualSelector"] | false |
    Then the step should fail
    And the output should contain:
      | `selector` not auto-generated |

  # @author qwang@redhat.com
  # @case_id OCP-10734
  @inactive
  Scenario: Create job with different pod restartPolicy
    Given I have a project
    Given I obtain test data file "job/job-restartpolicy.yaml"
    # Create job without restartPolicy
    And I replace lines in "job-restartpolicy.yaml":
      | from: Never | from: null |
    When I process and create:
      | f | job-restartpolicy.yaml |
    Then the step should fail
    And the output should match:
      | Unsupported value:\s+"Always":\s+supported values:\s+"?OnFailure"?,\s+"?Never"? |
    # Create job with restartPolicy=Never
    Given I replace lines in "job-restartpolicy.yaml":
      | from: null | from: Never |
    When I process and create:
      | f | job-restartpolicy.yaml |
    Then the step should succeed
    And I wait until job "pi-restartpolicy" completes
    When I get project pods
    Then the output should match:
      | Completed\\s+0 |
    When I get project job
    Then the output should match:
      | 1\\s+1 |
    # Create job with restartPolicy=OnFailure
    When I run the :delete client command with:
      | object_type       | job              |
      | object_name_or_id | pi-restartpolicy |
    Then the step should succeed
    Given all existing pods die with labels:
      | app=pi |
    And I replace lines in "job-restartpolicy.yaml":
      | from: Never | from: OnFailure |
    When I process and create:
      | f | job-restartpolicy.yaml   |
    Then the step should succeed
    And I wait until job "pi-restartpolicy" completes
    When I get project pods
    Then the output should match:
      | Completed\\s+0 |
    When I get project job
    Then the output should match:
      | 1\\s+1 |
    # Create job with restartPolicy=Never and make sure the pod never restart even there is error
    When I run the :delete client command with:
      | object_type       | job              |
      | object_name_or_id | pi-restartpolicy |
    Then the step should succeed
    Given all existing pods die with labels:
      | app=pi |
    Given I replace lines in "job-restartpolicy.yaml":
      | openshift/perl-516-centos7 | openshift/perl-516-centos |
    And I replace lines in "job-restartpolicy.yaml":
      | from: OnFailure | from: Never |
    When I process and create:
      | f | job-restartpolicy.yaml |
    Then the step should succeed
    When I wait up to 300 seconds for the steps to pass:
    """
    When I get project pods
    Then the output should match:
      | (Err)?ImagePull(BackOff)?\\s+0 |
    """
    When I get project job
    Then the output should match:
      | 1\\s+0 |
    # Create job with restartPolicy=OnFailure and make sure the pod is restared when error
    When I run the :delete client command with:
      | object_type       | job              |
      | object_name_or_id | pi-restartpolicy |
    Then the step should succeed
    Given all existing pods die with labels:
      | app=pi |
    Given I replace lines in "job-restartpolicy.yaml":
      | openshift/perl-516-centos | openshift/perl-516-centos7 |
      | - perl                    | - hello                    |
    And I replace lines in "job-restartpolicy.yaml":
      | from: Never | from: OnFailure |
    When I process and create:
      | f | job-restartpolicy.yaml   |
    Then the step should succeed
    When I wait up to 300 seconds for the steps to pass:
    """
    When I get project pods
    Then the output should match:
      | (CrashLoopBackOff\|RunContainerError\|CreateContainerError) |
    """
    When I get project job
    Then the output should match:
      | 1\\s+0 |
    # Create job with restartPolicy=Always
    When I run the :delete client command with:
      | object_type       | job              |
      | object_name_or_id | pi-restartpolicy |
    Then the step should succeed
    Given all existing pods die with labels:
      | app=pi |
    And I replace lines in "job-restartpolicy.yaml":
      | from: OnFailure | from: Always |
    When I process and create:
      | f | job-restartpolicy.yaml |
    Then the step should fail
    And the output should match:
      | Unsupported value:\s+"Always":\s+supported values:\s+"?OnFailure"?,\s+"?Never"? |

  # @author yinzhou@redhat.com
  # @case_id OCP-10781
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Create job with specific deadline
    Given I have a project
    Given I obtain test data file "job/job_with_0_activeDeadlineSeconds.yaml"
    When I run the :create client command with:
      | f | job_with_0_activeDeadlineSeconds.yaml |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | job  |
      | resource_name | zero |
      |  o            | yaml |
    And the expression should be true> @result[:parsed]['status']['conditions'][0]['reason'] == "DeadlineExceeded"
    When I run the :delete client command with:
      | object_type       | job  |
      | object_name_or_id | zero |
    Then the step should succeed
    Given I obtain test data file "job/job_with_negative_activeDeadlineSeconds.yaml"
    When I run the :create client command with:
      | f | job_with_negative_activeDeadlineSeconds.yaml |
    Then the step should fail
    And the output should contain:
      | Invalid value: |
    Given I obtain test data file "job/job_with_string_activeDeadlineSeconds.yaml"
    When I run the :create client command with:
      | f | job_with_string_activeDeadlineSeconds.yaml  |
    Then the step should fail
    Given I obtain test data file "job/job_with_float_activeDeadlineSeconds.yaml"
    When I run the :create client command with:
      | f | job_with_float_activeDeadlineSeconds.yaml |
    Then the step should fail
    Given I obtain test data file "job/job_with_lessthan_runtime_activeDeadlineSeconds.yaml"
    When I run the :create client command with:
      | f | job_with_lessthan_runtime_activeDeadlineSeconds.yaml |
    Then the step should succeed
    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | job  |
      | resource_name | pi   |
      |  o            | yaml |
    And the expression should be true> @result[:parsed]['status']['conditions'][0]['reason'] == "DeadlineExceeded"
    """
    When I run the :delete client command with:
      | object_type       | job |
      | object_name_or_id | pi  |
    Then the step should succeed
    Given I obtain test data file "job/job_with_long_activeDeadlineSeconds.yaml"
    When I run the :create client command with:
      | f | job_with_long_activeDeadlineSeconds.yaml |
    Then the step should succeed
    And I wait until job "pi" completes

  # @author geliu@redhat.com
  # @case_id OCP-17515
  @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: User can schedule a Cronjob execution with cron format time
    Given I have a project
    When I run the :create_cronjob client command with:
       | name             | sj3       |
       | image            | busybox   |
       | restart          | Never     |
       | schedule         | * * * * * |
       | oc_opts_end      |           |
       | exec_command     | sleep     |
       | exec_command_arg | 300       |
    Then the step should succeed
    And the expression should be true> cron_job('sj3').schedule == "* * * * *"
    When I run the :create_cronjob client command with:
       | name             | sj4       |
       | image            | busybox   |
       | restart          | Never     |
       | schedule         | 0 * * * * |
       | oc_opts_end      |           |
       | exec_command     | sleep     |
       | exec_command_arg | 300       |
    Then the step should succeed
    And the expression should be true> cron_job('sj4').schedule == "0 * * * *"
    When I run the :create_cronjob client command with:
       | name             | sj5        |
       | image            | busybox    |
       | restart          | Never      |
       | schedule         | * 12 * * * |
       | oc_opts_end      |            |
       | exec_command     | sleep      |
       | exec_command_arg | 300        |
    Then the step should succeed
    And the expression should be true> cron_job('sj5').schedule == "* 12 * * *"
    When I run the :create_cronjob client command with:
       | name             | sj6       |
       | image            | busybox   |
       | restart          | Never     |
       | schedule         | * * 1 * * |
       | oc_opts_end      |           |
       | exec_command     | sleep     |
       | exec_command_arg | 300       |
    Then the step should succeed
    And the expression should be true> cron_job('sj6').schedule == "* * 1 * *"
    When I run the :create_cronjob client command with:
       | name             | sj7       |
       | image            | busybox   |
       | restart          | Never     |
       | schedule         | * * * 4 * |
       | oc_opts_end      |           |
       | exec_command     | sleep     |
       | exec_command_arg | 300       |
    Then the step should succeed
    And the expression should be true> cron_job('sj7').schedule == "* * * 4 *"
    When I run the :create_cronjob client command with:
       | name             | sj8       |
       | image            | busybox   |
       | restart          | Never     |
       | schedule         | * * * * 3 |
       | oc_opts_end      |           |
       | exec_command     | sleep     |
       | exec_command_arg | 300       |
    Then the step should succeed
    And the expression should be true> cron_job('sj8').schedule == "* * * * 3"
    When I run the :create_cronjob client command with:
       | name             | sja        |
       | image            | busybox    |
       | restart          | Never      |
       | schedule         | 0 12 * * * |
       | oc_opts_end      |            |
       | exec_command     | sleep      |
       | exec_command_arg | 300        |
    Then the step should succeed
    And the expression should be true> cron_job('sja').schedule == "0 12 * * *"
    When I run the :create_cronjob client command with:
       | name             | sjb          |
       | image            | busybox      |
       | restart          | Never        |
       | schedule         | 0 12 15 11 3 |
       | oc_opts_end      |              |
       | exec_command     | sleep        |
       | exec_command_arg | 300          |
    Then the step should succeed
    And the expression should be true> cron_job('sjb').schedule == "0 12 15 11 3"
    When I run the :create_cronjob client command with:
       | name             | sjc           |
       | image            | busybox       |
       | restart          | Never         |
       | schedule         | 70 12 15 11 3 |
       | oc_opts_end      |               |
       | exec_command     | sleep         |
       | exec_command_arg | 300           |
    Then the step should fail
    And the output should match:
       | Invalid value: "70 12 15 11 3":                 |
       | [eE]nd of range \(70\) above maximum \(59\): 70 |
    When I run the :create_cronjob client command with:
       | name             | sjc          |
       | image            | busybox      |
       | restart          | Never        |
       | schedule         | 30 25 15 1 3 |
       | oc_opts_end      |              |
       | exec_command     | sleep        |
       | exec_command_arg | 300          |
    Then the step should fail
    And the output should match:
       | Invalid value: "30 25 15 1 3":                  |
       | [eE]nd of range \(25\) above maximum \(23\): 25 |
    When I run the :create_cronjob client command with:
       | name             | sjc          |
       | image            | busybox      |
       | restart          | Never        |
       | schedule         | 30 8 35 11 3 |
       | oc_opts_end      |              |
       | exec_command     | sleep        |
       | exec_command_arg | 300          |
    Then the step should fail
    And the output should match:
       | Invalid value: "30 8 35 11 3":                  |
       | [eE]nd of range \(35\) above maximum \(31\): 35 |
    When I run the :create_cronjob client command with:
       | name             | sjc         |
       | image            | busybox     |
       | restart          | Never       |
       | schedule         | 30 8 1 13 3 |
       | oc_opts_end      |             |
       | exec_command     | sleep       |
       | exec_command_arg | 300         |
    Then the step should fail
    And the output should match:
      | Invalid value: "30 8 1 13 3":                   |
      | [eE]nd of range \(13\) above maximum \(12\): 13 |
    When I run the :create_cronjob client command with:
       | name             | sjc        |
       | image            | busybox    |
       | restart          | Never      |
       | schedule         | 30 8 1 8 7 |
       | oc_opts_end      |            |
       | exec_command     | sleep      |
       | exec_command_arg | 300        |
    Then the step should fail
    And the output should match:
       | Invalid value: "30 8 1 8 7":                 |
       | [eE]nd of range \(7\) above maximum \(6\): 7 |
    When I run the :create_cronjob client command with:
       | name             | sjd       |
       | image            | busybox   |
       | restart          | Never     |
       | schedule         | @every 5m |
       | oc_opts_end      |           |
       | exec_command     | sleep     |
       | exec_command_arg | 300       |
    Then the step should succeed
    And the expression should be true> cron_job('sjd').schedule == "@every 5m"
    When I run the :create_cronjob client command with:
       | name             | sje     |
       | image            | busybox |
       | restart          | Never   |
       | schedule         | @daily  |
       | oc_opts_end      |         |
       | exec_command     | sleep   |
       | exec_command_arg | 300     |
    Then the step should succeed
    And the expression should be true> cron_job('sje').schedule == "@daily"
