Feature: test logging and metrics related steps

  @admin
  @destructive
  Scenario: test uninstall
    Given the master version >= "3.5"
    Given I have a project
    And metrics service is uninstalled with ansible using:
      | inventory| https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/generic_uninstall_inventory |

  @admin
  @destructive
  Scenario: test install logging <= 3.4
    Given the master version <= "3.4"
    Given I create a project with non-leading digit name
    Given logging service is installed in the project using deployer:
      | deployer_config | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/default_deployer.yaml |

  @admin
  @destructive
  Scenario: test install metrics <= 3.4
    Given the master version <= "3.4"
    Given I create a project with non-leading digit name
    Given metrics service is installed in the project using deployer:
      | deployer_config | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/default_deployer.yaml |


  Scenario: test bulk insertions
    Given I have a project
    Given I perform the POST metrics rest request with:
      | project_name | <%= project.name %>                                                                                    |
      | path         | /metrics/gauges                                                                                        |
      | payload      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/test_data_bulk.json |
    Given I perform the GET metrics rest request with:
      | project_name | <%= project.name %> |
      | path         | /metrics/gauges     |
    Then the expression should be true> cb.metrics_data.count == 2
    # due to fact the top level query does not usually return the same order as the original
    # file, we need to specific to which metric to query if we want verify the contents stored
    Given I perform the GET metrics rest request with:
      | project_name | <%= project.name %> |
      | path         | /metrics/gauges     |
      | metrics_id   | free_memory         |
    Then the expression should be true> cb.metrics_data[0][:parsed]['minTimestamp'] == 1460111065369
    Then the expression should be true> cb.metrics_data[0][:parsed]['maxTimestamp'] == 1460151065369
    Given I perform the GET metrics rest request with:
      | project_name | <%= project.name %> |
      | path         | /metrics/gauges     |
      | metrics_id   | used_memory         |
    Then the expression should be true> cb.metrics_data[0][:parsed]['minTimestamp'] == 1234567890123
    Then the expression should be true> cb.metrics_data[0][:parsed]['maxTimestamp'] == 1321098211412

  @admin
  @destructive
  Scenario: Test unified logging installation
    Given I create a project with non-leading digit name
    Given logging service is installed in the system

  @admin
  @destructive
  Scenario: Test unified metrics installation
    Given I create a project with non-leading digit name
    Given metrics service is installed in the system

  @admin
  @destructive
  Scenario: Test unified metrics installation with user param
    Given I create a project with non-leading digit name
    Given metrics service is installed in the system using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-12305/inventory |

  Scenario: test post and get step
    Given I have a project
    Given I perform the POST metrics rest request with:
      | project_name | <%= project.name %>                                                                               |
      | path         | /metrics/gauges                                                                                   |
      | payload      | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/test_data.json |
    Given I perform the GET metrics rest request with:
      | project_name | <%= project.name %> |
      | path         | /metrics/gauges     |
    Then the expression should be true> @result[:exitstatus] == 200

  @admin
  @destructive
  Scenario: test new inventory loading for metrics
    Given metrics service is installed in the system using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/new_inventory_format/logging_metrics/OCP-12276/inventory |
    Then the expression should be true> rc('hawkular-cassandra-1').container_spec(name: 'hawkular-cassandra-1').memory_limit_raw == "1G"
    Then the expression should be true> rc('hawkular-metrics').container_spec(user: user, name: 'hawkular-metrics').cpu_request_raw == "100m"

  @admin
  @destructive
  Scenario: test new inventory loading for logging
    Given the master version >= "3.4"
    And logging service is installed with ansible using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/new_inventory_format/logging_metrics/OCP-16138/inventory |
    Given a pod becomes ready with labels:
      | component=fluentd,logging-infra=fluentd |
    Then the expression should be true> pod.env_var('BUFFER_QUEUE_LIMIT') == "512"
    Then the expression should be true> pod.env_var('BUFFER_SIZE_LIMIT') == "2m"

  @admin
  @destructive
  Scenario: test new inventory loading for prometheus
    Given the master version >= "3.7"
    And metrics service is installed with ansible using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/new_inventory_format/logging_metrics/OCP-15529/inventory |
    And a pod becomes ready with labels:
      | app=prometheus |
    # check the parameter for the 5 containers
    #  ["prom-proxy", "prometheus", "alerts-proxy", "alert-buffer", "alertmanager"]
    # check prometheus container
    And the expression should be true> pod.container(name: 'prometheus').spec.cpu_limit_raw == '400m'
    And the expression should be true> pod.container(name: 'prometheus').spec.memory_limit_raw == '512Mi'
    And the expression should be true> pod.container(name: 'prometheus').spec.cpu_request_raw == '200m'
    And the expression should be true> pod.container(name: 'prometheus').spec.memory_request_raw == '256Mi'
    # check alertmanager container
    And the expression should be true> pod.container(name: 'alertmanager').spec.cpu_limit_raw == '500m'
    And the expression should be true> pod.container(name: 'alertmanager').spec.memory_limit_raw == '1Gi'
    And the expression should be true> pod.container(name: 'alertmanager').spec.cpu_request_raw == '256m'
    And the expression should be true> pod.container(name: 'alertmanager').spec.memory_request_raw == '512Mi'
    # check alertbuffer container
    And the expression should be true> pod.container(name: 'alert-buffer').spec.cpu_limit_raw == '400m'
    And the expression should be true> pod.container(name: 'alert-buffer').spec.memory_limit_raw == '1Gi'
    And the expression should be true> pod.container(name: 'alert-buffer').spec.cpu_request_raw == '256m'
    And the expression should be true> pod.container(name: 'alert-buffer').spec.memory_request_raw == '512Mi'
    # check oauth_proxy container
    And the expression should be true> pod.container(name: 'prom-proxy').spec.cpu_limit_raw == '200m'
    And the expression should be true> pod.container(name: 'prom-proxy').spec.memory_limit_raw == '500Mi'
    And the expression should be true> pod.container(name: 'prom-proxy').spec.cpu_request_raw == '200m'
    And the expression should be true> pod.container(name: 'prom-proxy').spec.memory_request_raw == '500Mi'

  @admin
  Scenario: test ssh key sync to pod
    Given I have a project
    And the expression should be true> cb.org_proj = project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/busybox-pod.yaml |
    Then the step should succeed
    Given the pod named "my-pod" becomes ready
    Given I create a project with non-leading digit name
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
    And a pod becomes ready with labels:
      | name=hello-openshift |
    And ssh key for accessing nodes is copied to the pod
    And I use the "<%= cb.org_proj.name %>" project
    And ssh key for accessing nodes is copied to the "tmp" directory in the "my-pod" pod

  @admin
  @destructive
  Scenario: test running user specified playbook
    Given the master version >= "3.5"
    Given I create a project with non-leading digit name
    # the clean up steps registered with the install step will be using uninstall
    And logging service is installed with ansible using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-12377/inventory |
    And I use the "<%= cb.org_project_for_ansible.name %>" project
    And I git clone the repo "https://github.com/openshift-qe/int_svc_playbooks.git" to "/tmp/tmp" in the "base-ansible-pod" pod
    And I run the following playbook on the pod:
      | playbook_path | int_svc_playbooks/internal-fluentd.yml |
      | clean_up_arg  | -e test_clear=true                     |
    And the step should succeed
    And I use the "<%= cb.target_proj %>" project
    # check fluentd forwrd pod is created by the user playbook
    And a pod becomes ready with labels:
      | component=forward-fluentd |
    # the original fluentd pod deleted and a new one generated, check it's functional
    And a pod becomes ready with labels:
      | component=fluentd |

