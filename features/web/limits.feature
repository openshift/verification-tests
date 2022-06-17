Feature: functions about resource limits on pod

  # @author yapei@redhat.com
  # @case_id OCP-10773
  @admin
  Scenario: OCP-10773 Specify resource constraints for standalone rc and dc in web console with project limits already set
    Given I create a new project
    # create limits and DC
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/limits/518638/limits.yaml |
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/dc-with-two-containers.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    # wait #1 deployment complete
    And I wait until the status of deployment "dctest" becomes :complete
    # go to set resource limit page
    When I perform the :goto_set_resource_limits_for_dc web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | dctest              |
    Then the step should succeed
    # set container 'dctest-1' memory limit amount < memory min limit amount
    When I perform the :set_resource_limit web console action with:
      | container_name  | dctest-1   |
      | resource_type   | memory     |
      | sequence_id     | 1          |
      | limit_type      | Limit      |
      | amount_unit     | MiB        |
      | resource_amount | 4          |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be less than 5 MiB |
    Then the step should succeed
    # set container 'dctest-1' memory limit in valid range, others keep as default
    When I perform the :set_resource_limit web console action with:
      | container_name  | dctest-1   |
      | resource_type   | memory     |
      | sequence_id     | 1          |
      | limit_type      | Limit      |
      | amount_unit     | MiB        |
      | resource_amount | 118        |
    Then the step should succeed
    # save changes
    When I run the :click_save_button web console action
    Then the step should succeed
    # wait #2 deployment is complete
    Given I wait for the pod named "dctest-2-deploy" to die
    And a pod becomes ready with labels:
      | deployment=dctest-2     |
    # check pod resources
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>              |
      | pod_name       | <%= pod.name %>                  |
      | container_name | dctest-1                         |
      | cpu_range      | 110 millicores to 130 millicores |
      | memory_range   | 118 MiB to 118 MiB               |
    Then the step should succeed
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>              |
      | pod_name       | <%= pod.name %>                  |
      | container_name | dctest-2                         |
      | cpu_range      | 110 millicores to 130 millicores | 
      | memory_range   | 256 MiB to 256 MiB               |
    Then the step should succeed

    # create standalone rc with multi containers
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/rc-with-two-containers.yaml" replacing paths:
      | ["spec"]["replicas"] | 0 |
    Then the step should succeed
    # set resource limits for standalone rc
    When I perform the :goto_set_resource_limits_for_rc web console action with:
      | project_name | <%= project.name %> |
      | rc_name      | rctest              |
    Then the step should succeed
    When I perform the :check_warn_info_for_rc_resource_setting web console action with:
      | rc_resource_setting_warn_info |  Changes will only apply to new pods |
    Then the step should succeed
    # set Container hello-openshift-fedora memory request amount > memory max limit amount in different units
    When I perform the :set_resource_limit web console action with:
      | container_name  | hello-openshift-fedora |
      | resource_type   | memory     |
      | sequence_id     | 1          |
      | limit_type      | Request    |
      | amount_unit     | MB         |
      | resource_amount | 786.44     |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 750 MiB |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Limit can't be less than request (786.44 MB) |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Memory request total for all containers is greater than pod maximum (750 MiB) |
    Then the step should succeed
    # set Container hello-openshift-fedora memory limit in valid range, others keep as default
    When I perform the :set_resource_limit web console action with:
      | container_name  | hello-openshift-fedora |
      | resource_type   | memory     |
      | sequence_id     | 1          |
      | limit_type      | Request    |
      | amount_unit     | MiB        |
      | resource_amount | 97         |
    Then the step should succeed
    # save changes
    When I run the :click_save_button web console action
    Then the step should succeed
    # scale rc 'rctest' to generate new pods
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | rctest                 |
      | replicas | 1                      |
    Then the step should succeed
    # wait new pod generated for rctest
    Given a pod becomes ready with labels:
      | run=rctest  |
    # check new pod resource limit info
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>              |
      | pod_name       | <%= pod.name %>                  |
      | container_name | hello-openshift                  |
      | cpu_range      | 110 millicores to 130 millicores |
      | memory_range   | 256 MiB to 256 MiB               |
    Then the step should succeed
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>              |
      | pod_name       | <%= pod.name %>                  |
      | container_name | hello-openshift-fedora           |
      | cpu_range      | 110 millicores to 130 millicores |
      | memory_range   | 97 MiB to 256 MiB                |
    Then the step should succeed

