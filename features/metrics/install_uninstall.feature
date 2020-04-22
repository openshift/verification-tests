Feature: metrics logging and uninstall tests

  # @author pruan@redhat.com
  # @case_id OCP-12234
  @admin
  @destructive
  Scenario: Metrics Admin Command - fresh deploy with default values
    Given I create a project with non-leading digit name
    Given the master version >= "3.5"
    And metrics service is installed with ansible using:
      | inventory | <%= BushSlicer::HOME %>/testdata/logging_metrics/OCP-12234/inventory |

  # @author pruan@redhat.com
  # @case_id OCP-12305
  @admin
  @destructive
  Scenario: Metrics Admin Command - clean and install
    Given the master version >= "3.5"
    Given I create a project with non-leading digit name
    And metrics service is installed with ansible using:
      | inventory | <%= BushSlicer::HOME %>/testdata/logging_metrics/OCP-12305/inventory |
    Given I remove metrics service using ansible
    And I use the "default" project
    And I wait for the resource "pod" named "base-ansible-pod" to disappear
    # reinstall it again
    And metrics service is installed with ansible using:
      | inventory | <%= BushSlicer::HOME %>/testdata/logging_metrics/OCP-12305/inventory |

  # @author pruan@redhat.com
  # @case_id OCP-17163
  @admin
  @destructive
  Scenario: deploy metrics with dynamic volume along with OCP
    Given the master version >= "3.7"
    Given I create a project with non-leading digit name
    And metrics service is installed in the system using:
      | inventory | <%= BushSlicer::HOME %>/testdata/logging_metrics/OCP-17163/inventory |
    And a pod becomes ready with labels:
      | metrics-infra=hawkular-cassandra |
    # 3 steps to verify hawkular-cassandra pod using mount correctly
    # 1. pvc working
    Then the expression should be true> pvc('metrics-cassandra-1').ready?[:success]
    # 2. check pod volume name matches 'metrics-cassandra-1'
    Then the expression should be true> pod.volumes.find { |v| v.name == 'cassandra-data' && v.kind_of?(BushSlicer::PVCPodVolumeSpec) && v.claim.name == 'metrics-cassandra-1' }
    # 3. check volume cassandra-data was mounted to /cassandra_data" in pod spec
    Then the expression should be true> pod.container(name: 'hawkular-cassandra-1').spec.volume_mounts.select { |v| v['mountPath'] == "/cassandra_data" }.count > 0

