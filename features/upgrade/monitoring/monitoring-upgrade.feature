Feature: cluster monitoring related upgrade check
  # @author hongyli@redhat.com
  @upgrade-prepare
  @admin
  Scenario: cluster monitoring - prepare
    Given I switch to cluster admin pseudo user
    And I use the "openshift-monitoring" project
    When I run the :apply client command with:
      | f          | <%= BushSlicer::HOME %>/features/upgrade/monitoring/cm-monitoring-retention.yaml |
      | overwrite  | true |
    Then the step should succeed

  # @author hongyli@redhat.com
  # @case_id OCP-29797
  @upgrade-check
  @admin
  Scenario: upgrade cluster monitoring along with OCP
    Given the first user is cluster-admin
    And I use the "openshift-monitoring" project
    When I run the :get client command with:
      | resource | pods |
    Then evaluation of `@result[:stdout].split(/\n/).drop(1).map {|n| n.split(/\s+/)[2]}` is stored in the :pod_status clipboard
    And I repeat the following steps for each :status in cb.pod_status:
    """
    Then the expression should be true> cb.status == "Running"
    """
    Then the output should contain 21 times:
      | Running |
    Then the output should not contain:
      | Terminating       |
      | ContainerCreating |
      | Pending           |
      | Failed            |
      | Unknown           |
    When I run the :get client command with:
      | resource | clusteroperator/monitoring |
    And evaluation of `@result[:stdout].split(/\n/)[1].split(/\s+/)[4]` is stored in the :degreaded_status clipboard
    #check retention time
    When I run the :get client command with:
      | resource | prometheus/k8s |
      | o        | yaml           |
    Then the expression should be true> YAML.load(@result[:stdout])["spec"]["retention"] == "3h"

    # get sa/prometheus-k8s token
    When evaluation of `secret(service_account('prometheus-k8s').get_secret_names.find {|s| s.match('token')}).token` is stored in the :sa_token clipboard

    # curl -k -H "Authorization: Bearer $token" 'https://prometheus-k8s.openshift-monitoring.svc:9091/api/v1/query?query=machine_cpu_cores'
    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | sh                   |
      | exec_command_arg | -c                   |
      | exec_command_arg | curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://prometheus-k8s.openshift-monitoring.svc:9091/api/v1/query?query=machine_cpu_cores |
    Then the step should succeed
    And the output should contain:
      | "status":"success"             |
      | "__name__":"machine_cpu_cores" |

    # curl -k -H "Authorization: Bearer $token" 'https://alertmanager-main.openshift-monitoring.svc:9094/api/v1/alerts'
    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | sh                   |
      | exec_command_arg | -c                   |
      | exec_command_arg | curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://alertmanager-main.openshift-monitoring.svc:9094/api/v1/alerts |
    Then the step should succeed
    And the output should contain:
      | "status":"success"             |
      | "alertname":"Watchdog" |

    # curl -k -H "Authorization: Bearer $token" 'https://grafana.openshift-monitoring.svc:3000/api/health
    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | sh                   |
      | exec_command_arg | -c                   |
      | exec_command_arg | curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://grafana.openshift-monitoring.svc:3000/api/health |
    Then the step should succeed
    And the output should contain:
      | "database": "ok" |
    When I run the :oadm_top_node admin command
    Then the output should contain:
      | CPU(cores) |