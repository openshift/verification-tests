Feature: oc_set_probe.feature

  # @author dyan@redhat.com
  # @case_id OCP-9870
  @inactive
  Scenario: OCP-9870:ImageRegistry Set a probe to open a TCP socket
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/mysql:latest |
      | env          | MYSQL_USER=user        |
      | env          | MYSQL_PASSWORD=pass    |
      | env          | MYSQL_DATABASE=db      |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :complete
    When I run the :set_probe client command with:
      | resource     | dc/mysql     |
      | readiness    |              |
      | open_tcp     | 3306         |
      | failure_threshold | 2          |
      | initial_delay_seconds | 10     |
      | period_seconds | 10            |
      | success_threshold | 3          |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :complete
    And a pod becomes ready with labels:
      | deployment=mysql-2 |
    When I run the :describe client command with:
      | resource | pod |
      | l    | deployment=mysql-2 |
    Then the output should match:
      | Readiness |
      | tcp-socket :3306 |
      | delay=10s |
      | period=10s |
      | success=3 |
      | failure=2 |
    When I run the :set_probe client command with:
      | resource     | dc/mysql    |
      | readiness    |             |
      | open_tcp     | 45          |
      | o            | json        |
    Then the step should succeed
    When I save the output to file> file.json
    And I run the :set_probe client command with:
      | f         | file.json   |
      | readiness |             |
      | open_tcp  | 33          |
    Then the step should succeed
    When I wait until the status of deployment "mysql" becomes :running
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
      | l    | deployment=mysql-4 |
    Then the output should match:
      | Readiness |
      | tcp-socket :33 |
      | probe failed |
    """

  # @author dyan@redhat.com
  # @case_id OCP-9871
  @inactive
  Scenario: OCP-9871:ImageRegistry Set a probe over HTTPS/HTTP
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/mysql:latest |
      | env          | MYSQL_USER=user        |
      | env          | MYSQL_PASSWORD=pass    |
      | env          | MYSQL_DATABASE=db      |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :complete
    When I run the :set_probe client command with:
      | resource     | dc/mysql  |
      | c            | mysql     |
      | readiness    |           |
      | get_url      | http://:8080/opt |
      | timeout_seconds | 30     |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :running
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
      | l    | deployment=mysql-2 |
    Then the output should contain:
      | Readiness |
      | http-get http://:8080/opt |
      | timeout=30s |
    """
    When I run the :set_probe client command with:
      | resource  | dc/mysql     |
      | readiness |              |
      | get_url   | https://127.0.0.1:1936/stats |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :running
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod |
      | l    | deployment=mysql-3 |
    Then the output should contain:
      | Readiness |
      | http-get https://127.0.0.1:1936/stats |
    """

  # @author dyan@redhat.com
  # @case_id OCP-9872
  @inactive
  Scenario: OCP-9872:ImageRegistry Set an exec action probe
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/mysql:latest |
      | env          | MYSQL_USER=user        |
      | env          | MYSQL_PASSWORD=pass    |
      | env          | MYSQL_DATABASE=db      |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :complete
    When I run the :set_probe client command with:
      | resource     | dc/mysql |
      | liveness     |          |
      | oc_opts_end  |          |
      | exec_command | true     |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :complete
    And a pod becomes ready with labels:
      | deployment=mysql-2 |
    When I run the :describe client command with:
      | resource | pod |
      | l    | deployment=mysql-2 |
    Then the output should contain:
      | Liveness     |
      | true         |
    When I run the :set_probe client command with:
      | resource     | dc/mysql |
      | liveness     |          |
      | oc_opts_end  |          |
      | exec_command | false    |
    Then the step should succeed
    Given I wait until the status of deployment "mysql" becomes :complete
    And a pod becomes ready with labels:
      | deployment=mysql-3 |
    When I run the :describe client command with:
      | resource | pod |
      | l    | deployment=mysql-3 |
    Then the output should contain:
      | Liveness     |
      | false        |

  # @author wewang@redhat.com
  # @case_id OCP-31241
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-31241:Workloads Set a probe to open a TCP socket test
    Given I have a project
    When I run the :create_deployment client command with:
      | name          | mysql                                                                                               |
      | image         | quay.io/openshifttest/mysql@sha256:0c76fd1a2eb31b0a196c7c557e4e56a11a6a8b26d745289e75fc983602035ba5 |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | deploy/mysql               |
      | e        | MARIADB_ROOT_PASSWORD=pass |
    Then the step should succeed
    Given "mysql" deployment becomes ready in the "<%= project.name %>" project
    When I run the :set_probe client command with:
      | resource              | deployment/mysql |
      | readiness             |                  |
      | open_tcp              | 3306             |
      | failure_threshold     | 2                |
      | initial_delay_seconds | 10               |
      | period_seconds        | 10               |
      | success_threshold     | 3                |
    Then the step should succeed
    Given "mysql" deployment becomes ready in the "<%= project.name %>" project
    And a pod becomes ready with labels:
      | app=mysql |
    When I run the :describe client command with:
      | resource | pod       |
      | l        | app=mysql |
    Then the output should match:
      | Readiness        |
      | tcp-socket :3306 |
      | delay=10s        |
      | period=10s       |
      | success=3        |
      | failure=2        |
    When I run the :set_probe client command with:
      | resource     | deployment/mysql |
      | readiness    |                  |
      | open_tcp     | 45               |
      | o            | json             |
    Then the step should succeed
    When I save the output to file> file.json
    And I run the :set_probe client command with:
      | f         | file.json   |
      | readiness |             |
      | open_tcp  | 33          |
    Then the step should succeed
    Given "mysql" deployment becomes ready in the "<%= project.name %>" project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod       |
      | l        | app=mysql |
    Then the output should match:
      | Readiness       |
      | tcp-socket :33  |
    """

  # @author wewang@redhat.com
  # @case_id OCP-31245
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-31245:Workloads Set a probe over HTTPS/HTTP test
    Given I have a project
    When I run the :create_deployment client command with:
      | name          | mysql                                                                                               |
      | image         | quay.io/openshifttest/mysql@sha256:0c76fd1a2eb31b0a196c7c557e4e56a11a6a8b26d745289e75fc983602035ba5 |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | deploy/mysql               |
      | e        | MARIADB_ROOT_PASSWORD=pass |
    Then the step should succeed
    When I run the :set_probe client command with:
      | resource        | deployment/mysql |
      | c               | mysql            |
      | readiness       |                  |
      | get_url         | http://:8080/opt |
      | timeout_seconds | 30               |
    Then the step should succeed
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod       |
      | l        | app=mysql |
    Then the output should contain:
      | Readiness                 |
      | http-get http://:8080/opt |
      | timeout=30s               |
    """
    When I run the :set_probe client command with:
      | resource  | deployment/mysql             |
      | readiness |                              |
      | get_url   | https://127.0.0.1:1936/stats |
    Then the step should succeed
    When I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | pod              |
      | l        | app=mysql |
    Then the output should contain:
      | Readiness                             |
      | http-get https://127.0.0.1:1936/stats |
    """

  # @author wewang@redhat.com
  # @case_id OCP-31246
  @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-31246:Workloads Set an exec action probe test
    Given I have a project
    When I run the :create_deployment client command with:
      | name          | mysql                                 |
      | image         | quay.io/openshifttest/mysql:1.2.0 |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | deploy/mysql               |
      | e        | MARIADB_ROOT_PASSWORD=pass |
    Then the step should succeed
    Given "mysql" deployment becomes ready in the "<%= project.name %>" project
    When I run the :set_probe client command with:
      | resource     | deployment/mysql |
      | liveness     |                  |
      | oc_opts_end  |                  |
      | exec_command | true             |
    Then the step should succeed
    Given "mysql" deployment becomes ready in the "<%= project.name %>" project
    And a pod becomes ready with labels:
      | app=mysql |
    When I run the :describe client command with:
      | resource | pod       |
      | l        | app=mysql |
    Then the output should contain:
      | Liveness |
      | true     |
    When I run the :set_probe client command with:
      | resource     | deployment/mysql |
      | liveness     |                  |
      | oc_opts_end  |                  |
      | exec_command | false            |
    Then the step should succeed
    Given "mysql" deployment becomes ready in the "<%= project.name %>" project
    And a pod becomes ready with labels:
      | app=mysql |
    When I run the :describe client command with:
      | resource | pod       |
      | l        | app=mysql |
    Then the output should contain:
      | Liveness     |
      | false        |
