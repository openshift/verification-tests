Feature: cluster monitoring related upgrade check

  # @author hongyli@redhat.com
  @upgrade-prepare
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @disconnected @connected
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @arm64 @amd64
  Scenario: upgrade cluster monitoring along with OCP - prepare
    Given I switch to cluster admin pseudo user
    Given I obtain test data file "monitoring/upgrade/cm-monitoring-retention.yaml"
    When I run the :apply client command with:
      | f         | cm-monitoring-retention.yaml |
      | overwrite | true |
    Then the step should succeed

  # @author hongyli@redhat.com
  # @case_id OCP-29797
  @upgrade-check
  @admin
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  Scenario: upgrade cluster monitoring along with OCP
    Given I switch to cluster admin pseudo user
    And I use the "openshift-monitoring" project
    # Check cluster operators should be in correct status
    Given the expression should be true> cluster_operator('monitoring').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('monitoring').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('monitoring').condition(type: 'Degraded')['status'] == "False"

    #check retention time
    Given the expression should be true> prometheus('k8s').retention == "3h"

    # get sa/prometheus-k8s token
    Given I find a bearer token of the prometheus-k8s service account
    When evaluation of `service_account('prometheus-k8s').cached_tokens.first` is stored in the :sa_token clipboard

    # curl -k -H "Authorization: Bearer $token" 'https://prometheus-k8s.openshift-monitoring.svc:9091/api/v1/query?query=cluster_installer'
    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | sh                   |
      | exec_command_arg | -c                   |
      | exec_command_arg | curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://prometheus-k8s.openshift-monitoring.svc:9091/api/v1/query?query=cluster_installer |
    Then the step should succeed
    And the output should contain:
      | "__name__":"cluster_installer" |

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
      | Watchdog |

    When I run the :oadm_top_node admin command
    Then the output should contain:
      | CPU(cores) |
