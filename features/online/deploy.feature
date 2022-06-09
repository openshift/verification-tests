Feature: ONLY ONLINE Deployment related scripts in this file

  # @author etrott@redhat.com
  # @case_id OCP-10075
  Scenario: OCP-10075 OSO Starter Specify resource constraints for standalone dc and rc in web console with project limits already set
    Given I have a project
    Given I obtain test data file "deployment/dc-with-two-containers.yaml"
    When I run the :create client command with:
      | f | dc-with-two-containers.yaml |
      | n | <%= project.name %>                                                                                       |
    Then the step should succeed
    And I wait until the status of deployment "dctest" becomes :complete
    Given I perform the :goto_set_resource_limits_for_dc web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | dctest              |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | MiB      |
      | resource_amount | 1100     |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 1 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | GiB      |
      | resource_amount | 1.1      |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 1 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | MiB      |
      | resource_amount | 800      |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Memory limit total for all containers is greater than pod maximum (1 GiB). |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | MiB      |
      | resource_amount | 255      |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    Given I wait for the pod named "dctest-2-deploy" to die
    And a pod becomes ready with labels:
      | deployment=dctest-2 |
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>  |
      | pod_name       | <%= pod.name %>      |
      | container_name | dctest-1             |
      | cpu_range      | 9 millicores to 498  |
      | memory_range   | 127 MiB to 255 MiB   |
    Then the step should succeed
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>  |
      | pod_name       | <%= pod.name %>      |
      | container_name | dctest-2             |
      | cpu_range      | 10 millicores to 500 |
      | memory_range   | 128 MiB to 256 MiB   |
    Then the step should succeed
    Given I obtain test data file "deployment/rc-with-two-containers.yaml"
    When I run the :create client command with:
      | f | rc-with-two-containers.yaml |
      | n | <%= project.name %>                                                                                       |
    Then the step should succeed
    When I perform the :goto_set_resource_limits_for_rc web console action with:
      | project_name | <%= project.name %> |
      | rc_name      | rctest              |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | sequence_id     | 1               |
      | amount_unit     | MiB             |
      | resource_amount | 1100            |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 1 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | sequence_id     | 1               |
      | amount_unit     | GiB             |
      | resource_amount | 1.1             |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 1 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | sequence_id     | 1               |
      | amount_unit     | MiB             |
      | resource_amount | 800             |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Memory limit total for all containers is greater than pod maximum (1 GiB). |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | amount_unit     | MiB             |
      | sequence_id     | 1               |
      | resource_amount | 255             |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | rctest                 |
      | replicas | 0                      |
    Then the step should succeed
    Given all existing pods die with labels:
      | run=rctest |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | rctest                 |
      | replicas | 1                      |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=rctest  |
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>  |
      | pod_name       | <%= pod.name %>      |
      | container_name | hello-openshift      |
      | cpu_range      | 9 millicores to 498  |
      | memory_range   | 127 MiB to 255 MiB   |
    Then the step should succeed
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>    |
      | pod_name       | <%= pod.name %>        |
      | container_name | hello-openshift-fedora |
      | cpu_range      | 10 millicores to 500   |
      | memory_range   | 128 MiB to 256 MiB     |
    Then the step should succeed

  # @author bingli@redhat.com
  # @case_id OCP-14969
  Scenario: OCP-14969 OSO Pro Specify resource constraints for standalone dc and rc in web console with project limits already set
    Given I have a project
    Given I obtain test data file "deployment/dc-with-two-containers.yaml"
    When I run the :create client command with:
      | f | dc-with-two-containers.yaml |
      | n | <%= project.name %>                                                                                       |
    Then the step should succeed
    And I wait until the status of deployment "dctest" becomes :complete
    Given I perform the :goto_set_resource_limits_for_dc web console action with:
      | project_name | <%= project.name %> |
      | dc_name      | dctest              |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | MiB      |
      | resource_amount | 3300     |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 3 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | GiB      |
      | resource_amount | 3.3      |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 3 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | MiB      |
      | resource_amount | 2900     |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Memory limit total for all containers is greater than pod maximum (3 GiB). |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | dctest-1 |
      | resource_type   | memory   |
      | sequence_id     | 1        |
      | amount_unit     | MiB      |
      | resource_amount | 500      |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    Given I wait for the pod named "dctest-2-deploy" to die
    And a pod becomes ready with labels:
      | deployment=dctest-2 |
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>  |
      | pod_name       | <%= pod.name %>      |
      | container_name | dctest-1             |
      | cpu_range      | 78 millicores to 976 |
      | memory_range   | 400 MiB to 500 MiB   |
    Then the step should succeed
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>  |
      | pod_name       | <%= pod.name %>      |
      | container_name | dctest-2             |
      | cpu_range      | 40 millicores to 500 |
      | memory_range   | 204 MiB to 256 MiB   |
    Then the step should succeed
    Given I obtain test data file "deployment/rc-with-two-containers.yaml"
    When I run the :create client command with:
      | f | rc-with-two-containers.yaml |
      | n | <%= project.name %>                                                                                       |
    Then the step should succeed
    When I perform the :goto_set_resource_limits_for_rc web console action with:
      | project_name | <%= project.name %> |
      | rc_name      | rctest              |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | sequence_id     | 1               |
      | amount_unit     | MiB             |
      | resource_amount | 3300            |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 3 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | sequence_id     | 1               |
      | amount_unit     | GiB             |
      | resource_amount | 3.3             |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Can't be greater than 3 GiB. |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | sequence_id     | 1               |
      | amount_unit     | MiB             |
      | resource_amount | 2900            |
    Then the step should succeed
    When I perform the :check_resource_limit_error_info web console action with:
      | error_info_for_resource_limit_setting | Memory limit total for all containers is greater than pod maximum (3 GiB). |
    Then the step should succeed
    When I perform the :set_resource_limit_online web console action with:
      | container_name  | hello-openshift |
      | resource_type   | memory          |
      | amount_unit     | MiB             |
      | sequence_id     | 1               |
      | resource_amount | 500             |
    Then the step should succeed
    When I run the :click_save_button web console action
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | rctest                 |
      | replicas | 0                      |
    Then the step should succeed
    Given all existing pods die with labels:
      | run=rctest |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | rctest                 |
      | replicas | 1                      |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | run=rctest  |
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>  |
      | pod_name       | <%= pod.name %>      |
      | container_name | hello-openshift      |
      | cpu_range      | 78 millicores to 976 |
      | memory_range   | 400 MiB to 500 MiB   |
    Then the step should succeed
    When I perform the :check_limits_on_pod_page web console action with:
      | project_name   | <%= project.name %>    |
      | pod_name       | <%= pod.name %>        |
      | container_name | hello-openshift-fedora |
      | cpu_range      | 40 millicores to 500   |
      | memory_range   | 204 MiB to 256 MiB     |
    Then the step should succeed

