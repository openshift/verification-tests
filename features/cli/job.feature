Feature: job.feature

  # @author cryan@redhat.com
  # @case_id OCP-11206
  Scenario: OCP-11206 Create job with multiple completions
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc511597/job.yaml |
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
    And the output should contain "3.14159"
    When I run the :delete client command with:
      | object_type | job |
      | object_name_or_id | pi |
    Then the step should succeed
    Given all existing pods die with labels:
      | app=pi |
    When I get project pods with labels:
      | app=pi |
    Then the step should succeed
    And the output should not contain "pi-"
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc511597/job.yaml" replacing paths:
      | ["spec"]["completions"] | -1 |
    Then the step should fail
    And the output should contain "must be greater than or equal to 0"
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc511597/job.yaml" replacing paths:
      | ["spec"]["completions"] | 0.1 |
    Then the step should fail

  # @author chezhang@redhat.com
  # @case_id OCP-11935
  Scenario: OCP-11935 Go through the job example
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job.yaml |
    Then the step should succeed
    When I get project pods
    Then the output should contain 5 times:
      | pi-      |
    Given status becomes :succeeded of exactly 5 pods labeled:
      | app=pi   |
    Then the step should succeed
    And I wait until job "pi" completes
    When I get project jobs
    Then the output should match:
      | pi.*5 |
    When I run the :describe client command with:
      | resource | jobs   |
      | name     | pi     |
    Then the output should match:
      | Name:\\s+pi                               |
      | Image.*\\s+openshift/perl-516-centos7     |
      | Selector:\\s+app=pi                       |
      | Parallelism:\\s+5                         |
      | Completions:\\s+<unset>                   |
      | Labels:\\s+app=pi                         |
      | Pods\\s+Statuses:\\s+0\\s+Running.*5\\s+Succeeded.*0\\s+Failed  |
    And the output should contain 5 times:
      | SuccessfulCreate  |
    When I get project pods
    Then the output should contain 5 times:
      | Completed         |
    When I run the :logs client command with:
      | resource_name     | <%= pod(-5).name %>   |
    Then the step should succeed
    And the output should contain:
      |  3.14159265       |

  # @author qwang@redhat.com
  # @case_id OCP-11539
  Scenario: OCP-11539 Create job with pod parallelism
    Given I have a project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | 1    |
      | ["spec"]["completions"]           | null |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should succeed
    Given 1 pods become ready with labels:
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
    And the output should contain "3.14159"
    # Delete job and check job and pod
    When I run the :delete client command with:
      | object_type       | job  |
      | object_name_or_id | zero |
    Then the step should succeed
    Given all existing pods die with labels:
      | app=pi |
    When I get project pods with labels:
      | app=pi |
    Then the output should not contain "zero-"
    # Create a job with invalid completions valuse
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | -1   |
      | ["spec"]["completions"]           | null |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should fail
    And the output should contain:
      | spec.parallelism |
      | must be greater than or equal to 0 |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["parallelism"]           | 0.1  |
      | ["spec"]["completions"]           | null |
      | ["spec"]["activeDeadlineSeconds"] | null |
    Then the step should fail
    # Create a job with both "parallelism" < "completions"
    Given all existing pods die with labels:
      | app=pi |
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_0_activeDeadlineSeconds.yaml" replacing paths:
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
    Given all existing pods die with labels:
      | app=pi |
    Then the step should succeed
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_0_activeDeadlineSeconds.yaml" replacing paths:
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
  Scenario: OCP-9948 Create job with activeDeadlineSeconds
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_lessthan_runtime_activeDeadlineSeconds.yaml |
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
  Scenario: OCP-9952 Specifying your own pod selector for job
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job-manualselector.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | job |
      | name     | pi  |
    Then the output should contain "controller-uid=64e92bd2-078d-11e6-a269-fa163e15bd57"
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_0_activeDeadlineSeconds.yaml" replacing paths:
      | ["spec"]["manualSelector"] | false |
    Then the step should fail
    And the output should contain:
      | `selector` not auto-generated |

  # @author qwang@redhat.com
  # @case_id OCP-10734
  Scenario: OCP-10734 Create job with different pod restartPolicy
    Given I have a project
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job-restartpolicy.yaml"
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
  Scenario: OCP-10781 Create job with specific deadline
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_0_activeDeadlineSeconds.yaml |
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
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_negative_activeDeadlineSeconds.yaml |
    Then the step should fail
    And the output should contain:
      | Invalid value: |
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_string_activeDeadlineSeconds.yaml  |
    Then the step should fail
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_float_activeDeadlineSeconds.yaml |
    Then the step should fail
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_lessthan_runtime_activeDeadlineSeconds.yaml |
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
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job_with_long_activeDeadlineSeconds.yaml |
    Then the step should succeed
    And I wait until job "pi" completes

  # @author chuyu@redhat.com
  # @case_id OCP-11644
  Scenario: OCP-11644 User can schedule a job execution with cron format time
    Given I have a project
    When I run the :run client command with:
       | name    | sj3          	|
       | image   | busybox    		|
       | restart | Never 		|
       | schedule| noescape: "* * * * *"|
       | sleep   | 300			|
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sj3  	        |
       | SCHEDULE | noescap: * * * * *  |
    When I run the :run client command with:
       | name    | sj4                  |
       | image   | busybox              |
       | restart | Never                |
       | schedule| noescape: "0 * * * *"|
       | sleep   | 300                  |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sj4                  |
       | SCHEDULE | noescap: 0 * * * *   |
    When I run the :run client command with:
       | name    | sj5                   |
       | image   | busybox               |
       | restart | Never                 |
       | schedule| noescape: "* 12 * * *"|
       | sleep   | 300                   |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sj5                  |
       | SCHEDULE | noescap: * 12 * * *  |
    When I run the :run client command with:
       | name    | sj6                   |
       | image   | busybox               |
       | restart | Never                 |
       | schedule| noescape: "* * 1 * *" |
       | sleep   | 300                   |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sj6                  |
       | SCHEDULE | noescap: * * 1 * *   |
    When I run the :run client command with:
       | name    | sj7                   |
       | image   | busybox               |
       | restart | Never                 |
       | schedule| noescape: "* * * 4 *" |
       | sleep   | 300                   |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sj7                  |
       | SCHEDULE | noescap: * * * 4 *   |
    When I run the :run client command with:
       | name    | sj8                   |
       | image   | busybox               |
       | restart | Never                 |
       | schedule| noescape: "* * * * 3" |
       | sleep   | 300                   |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sj8                  |
       | SCHEDULE | noescap: * * * * 3   |
    When I run the :run client command with:
       | name    | sja                   |
       | image   | busybox               |
       | restart | Never                 |
       | schedule| noescape: "0 12 * * *"|
       | sleep   | 300                   |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sja                  |
       | SCHEDULE | noescap: 0 12 * * *  |
    When I run the :run client command with:
       | name    | sjb                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "0 12 15 11 3"|
       | sleep   | 300                     |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sjb                    |
       | SCHEDULE | noescap: 0 12 15 11 3  |
    When I run the :run client command with:
       | name    | sjc                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "70 12 15 11 3"|
       | sleep   | 300                     |
    Then the step should fail
    And the output should contain:
       | Invalid value: "70 12 15 11 3": End of range (70) above maximum (59): 70 |
    When I run the :run client command with:
       | name    | sjc                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "30 25 15 1 3"|
       | sleep   | 300                     |
    Then the step should fail
    And the output should contain: 
       | Invalid value: "30 25 15 1 3": End of range (25) above maximum (23): 25 |
    When I run the :run client command with:
       | name    | sjc                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "30 8 35 11 3"|
       | sleep   | 300                     |
    Then the step should fail
    And the output should contain:
       | Invalid value: "30 8 35 11 3": End of range (35) above maximum (31): 35 |
    When I run the :run client command with:
       | name    | sjc                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "30 8 1 13 3" |
       | sleep   | 300                     |
    Then the step should fail
    And the output should contain:
       | Invalid value: "30 8 1 13 3": End of range (13) above maximum (12): 13 |
    When I run the :run client command with:
       | name    | sjc                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "30 8 1 8 7"  |
       | sleep   | 300                     |
    Then the step should fail
    And the output should contain:
       | Invalid value: "30 8 1 8 7": End of range (7) above maximum (6): 7 |
    When I run the :run client command with:
       | name    | sjd                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "@every 5m"   |
       | sleep   | 300                     |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sjd                    |
       | SCHEDULE | noescap: @every 5m     |
    When I run the :run client command with:
       | name    | sje                     |
       | image   | busybox                 |
       | restart | Never                   |
       | schedule| noescape: "@daily"      |
       | sleep   | 300                     |
    Then the step should succeed
    When I run the :get client command with:
       | resource | scheduledjobs|
    Then the step should succeed
    And the output should contain:
       | NAME     | sjd                    |
       | SCHEDULE | noescap: @daily        |

  # @author geliu@redhat.com
  # @case_id OCP-17515
  Scenario: OCP-17515 User can schedule a Cronjob execution with cron format time
    Given I have a project
    When I run the :run client command with:
       | name     | sj3       |
       | image    | busybox   |
       | restart  | Never     |
       | schedule | * * * * * |
       | sleep    | 300	     |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sj3        |
       | SCHEDULE | * * * * *  |
    When I run the :run client command with:
       | name     | sj4       |
       | image    | busybox   |
       | restart  | Never     |
       | schedule | 0 * * * * |
       | sleep    | 300       |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sj4       |
       | SCHEDULE | 0 * * * * |
    When I run the :run client command with:
       | name     | sj5        |
       | image    | busybox    |
       | restart  | Never      |
       | schedule | * 12 * * * |
       | sleep    | 300        |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sj5        |
       | SCHEDULE | * 12 * * * |
    When I run the :run client command with:
       | name     | sj6       |
       | image    | busybox   |
       | restart  | Never     |
       | schedule | * * 1 * * |
       | sleep    | 300       |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sj6       |
       | SCHEDULE | * * 1 * * |
    When I run the :run client command with:
       | name     | sj7       |
       | image    | busybox   |
       | restart  | Never     |
       | schedule | * * * 4 * |
       | sleep    | 300       |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sj7       |
       | SCHEDULE | * * * 4 * |
    When I run the :run client command with:
       | name     | sj8       |
       | image    | busybox   |
       | restart  | Never     |
       | schedule | * * * * 3 |
       | sleep    | 300       |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sj8       |
       | SCHEDULE | * * * * 3 |
    When I run the :run client command with:
       | name     | sja        |
       | image    | busybox    |
       | restart  | Never      |
       | schedule | 0 12 * * * |
       | sleep    | 300        |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sja        |
       | SCHEDULE | 0 12 * * * |
    When I run the :run client command with:
       | name     | sjb          |
       | image    | busybox      |
       | restart  | Never        |
       | schedule | 0 12 15 11 3 |
       | sleep    | 300          |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sjb          |
       | SCHEDULE | 0 12 15 11 3 |
    When I run the :run client command with:
       | name     | sjc           |
       | image    | busybox       |
       | restart  | Never         |
       | schedule | 70 12 15 11 3 |
       | sleep    | 300           |
    Then the step should fail
    And the output should contain:
       | Invalid value: "70 12 15 11 3": End of range (70) above maximum (59): 70 |
    When I run the :run client command with:
       | name     | sjc          |
       | image    | busybox      |
       | restart  | Never        |
       | schedule | 30 25 15 1 3 |
       | sleep    | 300          |
    Then the step should fail
    And the output should contain: 
       | Invalid value: "30 25 15 1 3": End of range (25) above maximum (23): 25 |
    When I run the :run client command with:
       | name     | sjc          |
       | image    | busybox      |
       | restart  | Never        |
       | schedule | 30 8 35 11 3 |
       | sleep    | 300          |
    Then the step should fail
    And the output should contain:
       | Invalid value: "30 8 35 11 3": End of range (35) above maximum (31): 35 |
    When I run the :run client command with:
       | name     | sjc         |
       | image    | busybox     |
       | restart  | Never       |
       | schedule | 30 8 1 13 3 |
       | sleep    | 300         |
    Then the step should fail
    And the output should contain:
       | Invalid value: "30 8 1 13 3": End of range (13) above maximum (12): 13 |
    When I run the :run client command with:
       | name     | sjc        |
       | image    | busybox    |
       | restart  | Never      |
       | schedule | 30 8 1 8 7 |
       | sleep    | 300        |
    Then the step should fail
    And the output should contain:
       | Invalid value: "30 8 1 8 7": End of range (7) above maximum (6): 7 |
    When I run the :run client command with:
       | name     | sjd       |
       | image    | busybox   |
       | restart  | Never     |
       | schedule | @every 5m |
       | sleep    | 300       |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sjd       |
       | SCHEDULE | @every 5m |
    When I run the :run client command with:
       | name     | sje     |
       | image    | busybox |
       | restart  | Never   |
       | schedule | @daily  |
       | sleep    | 300     |
    Then the step should succeed
    When I run the :get client command with:
       | resource | cronjob |
    Then the step should succeed
    And the output should contain:
       | NAME     | sjd    |
       | SCHEDULE | @daily |

