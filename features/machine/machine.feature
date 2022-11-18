Feature: Machine features testing

  # @author jhou@redhat.com
  # @case_id OCP-21196
  @smoke
  @admin
  @osd_ccs @aro @rosa
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @upgrade-sanity
  @singlenode
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-21196:ClusterInfrastructure Machines should be linked to nodes
    Given I have an IPI deployment
    Then the machines should be linked to nodes

  # @author jhou@redhat.com
  # @case_id OCP-22115
  @smoke
  @admin
  @aro
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-22115:ClusterInfrastructure machine-api clusteroperator should be in Available state
    Given evaluation of `cluster_operator('machine-api').condition(type: 'Available')` is stored in the :co_available clipboard
    Then the expression should be true> cb.co_available["status"]=="True"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Degraded')` is stored in the :co_degraded clipboard
    Then the expression should be true> cb.co_degraded["status"]=="False"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Upgradeable')` is stored in the :co_upgradable clipboard
    Then the expression should be true> cb.co_upgradable["status"]=="True"

    Given evaluation of `cluster_operator('machine-api').condition(type: 'Progressing')` is stored in the :co_progressing clipboard
    Then the expression should be true> cb.co_progressing["status"]=="False"

  # @author zhsun@redhat.com
  # @case_id OCP-37706
  @admin
  @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: OCP-37706:ClusterInfrastructure Baremetal clusteroperator should be disabled in any deployment that is not baremetal
    Given evaluation of `cluster_operator('baremetal').condition(type: 'Disabled')` is stored in the :co_disabled clipboard
    Then the expression should be true> cb.co_disabled["status"]=="True"

  # @author jhou@redhat.com
  # @case_id OCP-25436
  @admin
  @aro
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @upgrade-sanity
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-25436:ClusterInfrastructure Scale up and scale down a machineSet
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-25436"

    Given I scale the machineset to +2
    Then the step should succeed
    And the machineset should have expected number of running machines

    When I scale the machineset to -1
    Then the step should succeed
    And the machineset should have expected number of running machines


  # @author jhou@redhat.com
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Metrics is exposed on https
    Given the first user is cluster-admin
    And I use the "openshift-monitoring" project
    And evaluation of `service_account('prometheus-k8s').cached_tokens.first` is stored in the :token clipboard

    When I run the :exec admin command with:
      | n                | openshift-monitoring                                           |
      | pod              | prometheus-k8s-0                                               |
      | c                | prometheus                                                     |
      | oc_opts_end      |                                                                |
      | exec_command     | sh                                                             |
      | exec_command_arg | -c                                                             |
      | exec_command_arg | curl -v -s -k -H "Authorization: Bearer <%= cb.token %>" <url> |
    Then the step should succeed

    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @network-ovnkubernetes @network-openshiftsdn
    @proxy @noproxy @disconnected @connected
    @heterogeneous @arm64 @amd64
    @hypershift-hosted
    Examples:
      | case_id                         | url                                                                          |
      | OCP-25652:ClusterInfrastructure | https://machine-api-operator.openshift-machine-api.svc:8443/metrics          | # @case_id OCP-25652
      | OCP-26111:ClusterInfrastructure | https://cluster-autoscaler-operator.openshift-machine-api.svc:9192/metrics   | # @case_id OCP-26111
      | OCP-26102:ClusterInfrastructure | https://machine-approver.openshift-cluster-machine-approver.svc:9192/metrics | # @case_id OCP-26102

  # @author zhsun@redhat.com
  # @case_id OCP-25608
  @admin
  @aro
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-25608:ClusterInfrastructure Machine should have immutable field providerID and nodeRef
    Given I have an IPI deployment
    Given I store the last provisioned machine in the :machine clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).node_name` is stored in the :nodeRef_name clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).provider_id` is stored in the :providerID clipboard

    When I run the :patch admin command with:
      | resource      | machines.machine.openshift.io          |
      | resource_name | <%= cb.machine %>                      |
      | p             | {"status":{"nodeRef":{"name":"test"}}} |
      | type          | merge                                  |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    When I run the :describe admin command with:
      | resource      | machines.machine.openshift.io          |
      | name          | <%= cb.machine %>                      |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    And the output should match "Name:\s+<%= cb.nodeRef_name %>"

    When I run the :patch admin command with:
      | resource      | machines.machine.openshift.io          |
      | resource_name | <%= cb.machine %>                      |
      | p             | {"spec":{"providerID":"invalid"}}      |
      | type          | merge                                  |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe admin command with:
      | resource      | machines.machine.openshift.io                                |
      | name          | <%= cb.machine %>                      |
      | n             | openshift-machine-api                  |
    Then the step should succeed
    And the output should match "Provider ID:\s+<%= cb.providerID %>"
    """

  # @author miyadav@redhat.com
  # @case_id OCP-27627
  @admin
  @osd_ccs @aro
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @vsphere-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @hypershift-hosted
  Scenario: OCP-27627:ClusterInfrastructure Verify all machine instance-state should be consistent with their providerStats.instanceState
    Given I have an IPI deployment
    And evaluation of `BushSlicer::MachineMachineOpenshiftIo.list(user: admin, project: project('openshift-machine-api'))` is stored in the :machines clipboard
    Then the expression should be true> cb.machines.select{|m|m.instance_state == m.annotation_instance_state}.count == cb.machines.count

  # @author miyadav@redhat.com
  # @case_id OCP-27609
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-27609:ClusterInfrastructure Scaling a machineset with providerSpec.publicIp set to true
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-27609"
    Then as admin I successfully merge patch resource "machinesets.machine.openshift.io/machineset-clone-27609" with:
      | {"spec":{"template": {"spec":{"providerSpec":{"value":{"publicIP": true}}}}}} |
    And I scale the machineset to +2
    Then the machineset should have expected number of running machines

  # @author miyadav@redhat.com
  # @case_id OCP-24363
  @admin
  @aro
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-24363:ClusterInfrastructure Reconciling machine taints with nodes
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-24363"
    And evaluation of `machine_set_machine_openshift_io.machines.first.node_name` is stored in the :noderef_name clipboard
    And evaluation of `machine_set_machine_openshift_io.machines.first.name` is stored in the :machine_name clipboard

    Given I saved following keys to list in :taintsid clipboard:
      | {"spec":{"taints": [{"effect": "NoExecute","key": "role","value": "master"}]}}  | |
      | {"spec":{"taints": [{"effect": "NoSchedule","key": "role","value": "master"}]}} | |

    And I use the "openshift-machine-api" project
    Then I repeat the following steps for each :id in cb.taintsid:
    """
    Given as admin I successfully merge patch resource "machines.machine.openshift.io/<%= cb.machine_name %>" with:
      | #{cb.id} |
    Then the step should succeed
    """
    When I run the :describe admin command with:
      | resource | node                 |
      | name     |<%= cb.noderef_name %>|
    Then the output should contain:
      | role=master:NoExecute |
      | role=master:NoSchedule|

  # @author zhsun@redhat.com
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Required configuration should be added to the ProviderSpec to enable spot instances
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And admin ensures machine number is restored after scenario

    #Create a spot machineset
    Given I use the "openshift-machine-api" project
    Given I create a spot instance machineset and name it "<machineset_name>" on <iaas_type>
    And evaluation of `machine_set_machine_openshift_io.machines.first.node_name` is stored in the :noderef_name clipboard
    And evaluation of `machine_set_machine_openshift_io.machines.first.name` is stored in the :machine_name clipboard

    #Check machine and node were labelled as an `interruptible-instance`
    When I run the :describe admin command with:
      | resource | machines.machine.openshift.io |
      | name     | <%= cb.machine_name %>        |
    Then the step should succeed
    And the output should match "machine.openshift.io/interruptible-instance"
    When I run the :describe admin command with:
      | resource | node                   |
      | name     | <%= cb.noderef_name %> |
    Then the step should succeed
    And the output should match "machine.openshift.io/interruptible-instance="
    And "machine-api-termination-handler" daemonset becomes ready in the "openshift-machine-api" project
    And 1 pod becomes ready with labels:
      | k8s-app=termination-handler |

    # Create clusterautoscaler
    Given I obtain test data file "cloud/cluster-autoscaler.yml"
    When I run the :create admin command with:
      | f | cluster-autoscaler.yml |
    Then the step should succeed
    And admin ensures "default" clusterautoscaler is deleted after scenario
    And 1 pod becomes ready with labels:
      | cluster-autoscaler=default,k8s-app=cluster-autoscaler |

    # Create machineautoscaler
    Given I obtain test data file "cloud/machine-autoscaler.yml"
    When I run oc create over "machine-autoscaler.yml" replacing paths:
      | ["metadata"]["name"]               | maotest           |
      | ["spec"]["minReplicas"]            | 1                 |
      | ["spec"]["maxReplicas"]            | 3                 |
      | ["spec"]["scaleTargetRef"]["name"] | <machineset_name> |
    Then the step should succeed
    And admin ensures "maotest" machineautoscaler is deleted after scenario

    # Create workload
    Given I obtain test data file "cloud/autoscaler-auto-tmpl.yml"
    When I run the :create admin command with:
      | f | autoscaler-auto-tmpl.yml |
    Then the step should succeed
    And admin ensures "workload" job is deleted from the "openshift-machine-api" project after scenario

    # Verify machineset has scaled
    Given I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set_machine_openshift_io.desired_replicas(cached: false) == 3
    """
    Then the machineset should have expected number of running machines

    # Delete workload
    Given admin ensures "workload" job is deleted from the "openshift-machine-api" project
    # Check cluster auto scales down
    And I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set_machine_openshift_io.desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines

    # Check autoscaler taints are deleted when min node is reached
    Given I store the last provisioned machine in the :machine clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).node_name` is stored in the :noderef_name clipboard
    When I run the :describe admin command with:
      | resource | node                  |
      | name     | <%= cb.noderef_name%> |
    Then the step should succeed
    And the output should not contain:
      | DeletionCandidateOfClusterAutoscaler |
      | ToBeDeletedByClusterAutoscaler       |

    @aws-ipi
    Examples:
      | case_id                         | iaas_type | machineset_name        |
      | OCP-29199:ClusterInfrastructure | aws       | machineset-clone-29199 | # @case_id OCP-29199

    @gcp-ipi
    @heterogeneous @arm64 @amd64
    @proxy @noproxy @disconnected @connected
    @network-ovnkubernetes @network-openshiftsdn
    @hypershift-hosted
    Examples:
      | case_id                         | iaas_type | machineset_name        |
      | OCP-32126:ClusterInfrastructure | gcp       | machineset-clone-32126 | # @case_id OCP-32126

  # @author zhsun@redhat.com
  # @case_id OCP-32620
  @admin
  @aro
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-32620:ClusterInfrastructure Labels specified in a machineset should propagate to nodes
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    And admin ensures machine number is restored after scenario

    Given I clone a machineset and name it "machineset-clone-32620"
    Given as admin I successfully merge patch resource "machinesets.machine.openshift.io/machineset-clone-32620" with:
      | {"spec":{"template":{"spec":{"metadata":{"labels":{"node-role.kubernetes.io/infra": ""}}}}}} |
    Then the step should succeed

    Given I scale the machineset to +1
    Then the step should succeed
    And the machineset should have expected number of running machines

    #Check labels are propagate to nodes
    Given I store the last provisioned machine in the :machine clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).node_name` is stored in the :noderef_name clipboard
    When I run the :describe admin command with:
      | resource | node                   |
      | name     | <%= cb.noderef_name %> |
    Then the step should succeed
    And the output should match "node-role.kubernetes.io/infra="

  # @author miyadav@redhat.com
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Implement defaulting machineset values for AWS
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    Then admin ensures machine number is restored after scenario

    Given I pick a earliest created machineset and store in :machineset clipboard
    When evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_ami_id` is stored in the :default_ami_id clipboard
    And evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_availability_zone` is stored in the :default_availability_zone clipboard
    And evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_iamInstanceProfile` is stored in the :default_iamInstanceProfile clipboard
    And evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_subnet` is stored in the :default_subnet clipboard
    Then admin ensures "<name>" machine_set_machine_openshift_io is deleted after scenario

    Given I obtain test data file "cloud/ms-aws/<file_name>"
    When I run oc create over "<file_name>" replacing paths:
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]           | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["iamInstanceProfile"]["id"]         | <%= cb.default_iamInstanceProfile %>        |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"]        | <name>                                      |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-cluster"]    | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["ami"]["id"]                        | <%= cb.default_ami_id %>                    |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["placement"]["availabilityZone"]    | <%= cb.default_availability_zone %>         |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["subnet"]["filters"][0]["values"]   |  <%= cb.default_subnet[0].values[1] %>      |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-machineset"] | <name>                                      |
      | ["metadata"]["name"]                                                                      | <name>                                      |
    Then the step should succeed

    Then I store the last provisioned machine in the :machine_latest clipboard
    And I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_machine_openshift_io(cb.machine_latest).phase(cached: false) == "Running"
    """

    When I run the :describe admin command with:
      | resource | machines.machine.openshift.io |
      | name     | <%= cb.machine_latest %>      |
    Then the step should succeed
    And the output should contain:
      | <Validation> |

    @aws-ipi
    @noproxy @disconnected @connected
    @network-ovnkubernetes @network-openshiftsdn
    @heterogeneous @arm64 @amd64
    @hypershift-hosted
    Examples:
      | case_id                         | name                    | file_name                 | Validation                    |
      | OCP-32269:ClusterInfrastructure | default-valued-32269    | ms_default_values.yaml    | Placement                     | # @case_id OCP-32269
      | OCP-37132:ClusterInfrastructure | tenancy-dedicated-37132 | ms_tenancy_dedicated.yaml | Tenancy:            dedicated | # @case_id OCP-37132
      | OCP-42346:ClusterInfrastructure | default-valued-42346    | ms_default_values.yaml    | Instance Type:  m5.large      | # @case_id OCP-42346

  # @author miyadav@redhat.com
  # @case_id OCP-33056
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @gcp-ipi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-33056:ClusterInfrastructure Implement defaulting machineset values for GCP
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    Then admin ensures machine number is restored after scenario

    Given I store the last provisioned machine in the :machine clipboard
    When evaluation of `machine_machine_openshift_io(cb.machine).gcp_region` is stored in the :default_region clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).gcp_zone` is stored in the :default_zone clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).gcp_service_account` is stored in the :default_service_account clipboard
    Then admin ensures "default-valued-33056" machine_set_machine_openshift_io is deleted after scenario

    Given I obtain test data file "cloud/ms-gcp/ms_default_values.yaml"
    When I run oc create over "ms_default_values.yaml" replacing paths:
      | n                                                                                         | openshift-machine-api                                |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]           | <%= infrastructure("cluster").infra_name %>          |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"]        | default-valued-33056                                 |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-cluster"]    | <%= infrastructure("cluster").infra_name %>          |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["region"]                           | <%= cb.default_region %>                             |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["serviceAccounts"][0]["email"]      | <%=  cb.default_service_account[0].fetch("email") %> |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["zone"]                             | <%= cb.default_zone %>                               |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-machineset"] | default-valued-33056                                 |
    Then the step should succeed

    # Verify machine could be created successful
    And I wait up to 300 seconds for the steps to pass:
    """
    Then the expression should be true> machine_set_machine_openshift_io("default-valued-33056").desired_replicas(cached: false) == 1
    """
    Then the machineset should have expected number of running machines

  # @author miyadav@redhat.com
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Implement defaulting machineset values for azure
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    Then admin ensures machine number is restored after scenario

    Given I store the last provisioned machine in the :machine clipboard
    Then evaluation of `machine_machine_openshift_io(cb.machine).azure_location` is stored in the :default_location clipboard
    And admin ensures "<name>" machine_set_machine_openshift_io is deleted after scenario

    Given I obtain test data file "cloud/ms-azure/<file_name>"
    When I run oc create over "<file_name>" replacing paths:
      | n                                                                                         | openshift-machine-api                       |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]           | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"]        | <name>                                      |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-cluster"]    | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["location"]                         | <%= cb.default_location %>                  |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-machineset"] | <name>                                      |
      | ["metadata"]["name"]                                                                      | <name>                                      |
    Then the step should succeed

    Then I store the last provisioned machine in the :machine_latest clipboard
    And I wait up to 400 seconds for the steps to pass:
    """
    Then the expression should be true> machine_machine_openshift_io(cb.machine_latest).phase(cached: false) == "Running"
    """

    When I run the :describe admin command with:
      | resource | machines.machine.openshift.io |
      | name     | <%= cb.machine_latest %>      |
    Then the step should succeed
    And the output should contain:
      | <Validation> |

    @azure-ipi
    @network-ovnkubernetes @network-openshiftsdn
    @proxy @noproxy @disconnected @connected
    @heterogeneous @arm64 @amd64
    @hypershift-hosted
    Examples:
      | case_id                         | name                  | file_name               | Validation                |
      | OCP-33058:ClusterInfrastructure | default-valued-33058  | ms_default_values.yaml  | Public IP                 | # @case_id OCP-33058
      | OCP-39639:ClusterInfrastructure | encrypt-at-rest-39639 | ms_encrypt_at_rest.yaml | Encryption At Host:  true | # @case_id OCP-39639

  # @author miyadav@redhat.com
  # @case_id OCP-33455
  @admin
  @osd_ccs @aro
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @hypershift-hosted
  Scenario: OCP-33455:ClusterInfrastructure Run machine api Controllers using leader election
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project

    Given a pod becomes ready with labels:
      | api=clusterapi, k8s-app=controller |

    And I saved following keys to list in :containers clipboard:
      | machine-controller     | |
      | machineset-controller  | |
      | nodelink-controller    | |

    Then I repeat the following steps for each :id in cb.containers:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |
      | c             | #{cb.id}        |
    Then the output should match:
      | attempting to acquire leader lease (.*)openshift-machine-api/cluster-api-provider |
    """

  # @author miyadav@redhat.com
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Implement defaulting machineset values for vsphere
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    Then admin ensures machine number is restored after scenario

    Given I store the last provisioned machine in the :machine clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_datacenter` is stored in the :datacenter clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_datastore` is stored in the :datastore clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_folder` is stored in the :folder clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_resourcePool` is stored in the :resourcePool clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_server` is stored in the :server clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_diskGiB` is stored in the :diskGiB clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_memoryMiB` is stored in the :memoryMiB clipboard
    And evaluation of `machine_machine_openshift_io(cb.machine).vsphere_template` is stored in the :template clipboard
    Then admin ensures "<name>" machine_set_machine_openshift_io is deleted after scenario

    Given I obtain test data file "cloud/ms-vsphere/ms_default_values.yaml"
    When I run oc create over "ms_default_values.yaml" replacing paths:
      | n                                                                                         | openshift-machine-api                       |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]           | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"]        | <name>                                      |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-cluster"]    | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["workspace"]["datacenter"]          | <%= cb.datacenter %>                        |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["workspace"]["datastore"]           | <%= cb.datastore %>                         |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["workspace"]["folder"]              | <%= cb.folder %>                            |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["workspace"]["resourcePool"]        | <%= cb.resourcePool %>                      |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["workspace"]["server"]              | <%= cb.server %>                            |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["diskGiB"]                          | <diskGiB>                                   |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["memoryMiB"]                        | <%= cb.memoryMiB %>                         |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["template"]                         | <template>                                  |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-machineset"] | <name>                                      |
      | ["metadata"]["name"]                                                                      | <name>                                      |
    Then the step should succeed

    And I wait up to 120 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | machines.machine.openshift.io |
    Then the step should succeed
    And the output should contain:
      | Provisioned  |
    """

    @vsphere-ipi
    Examples:
      | case_id                         | name                 | template           | diskGiB           |
      | OCP-33380:ClusterInfrastructure | default-valued-33380 | <%= cb.template %> | <%= cb.diskGiB %> | # @case_id OCP-33380

    @network-ovnkubernetes @network-openshiftsdn
    @proxy @noproxy @disconnected @connected
    @heterogeneous @arm64 @amd64
    @hypershift-hosted
    Examples:
      | case_id   | name                         | template                           | diskGiB           |
      | OCP-35421:ClusterInfrastructure | default-valued-windows-35421 | openshift-qe-template-windows-2019 | 135               | # @case_id OCP-35421

  # @author miyadav@redhat.com
  # @case_id OCP-47658
  @admin
  @aro
  @4.13 @4.12 @4.11 @4.10
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @hypershift-hosted
  Scenario: OCP-47658:ClusterInfrastructure Operator cloud-controller-manager should not show empty version
    Given I switch to cluster admin pseudo user
    Then evaluation of `cluster_operator('cloud-controller-manager').versions` is stored in the :versions clipboard
    And the expression should be true> cb.versions[0].include? "4"

  # @author miyadav@redhat.com
  # @case_id OCP-47989
  @admin
  @4.12 @4.11 @4.10
  @vsphere-ipi @openstack-ipi @baremetal-ipi
  @vsphere-upi @openstack-upi @baremetal-upi
  @singlenode
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @hypershift-hosted
  Scenario: OCP-47989:ClusterInfrastructure Baremetal clusteroperator should be enabled in vsphere and osp
    Given evaluation of `cluster_operator('baremetal').condition(type: 'Disabled')` is stored in the :co_disabled clipboard
    Then the expression should be true> cb.co_disabled["status"]=="False"

  # @author miyadav@redhat.com
  @admin
  @destructive
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Implement defaulting machineset values for AWS proxy clusters
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    Then admin ensures machine number is restored after scenario

    Given I pick a earliest created machineset and store in :machineset clipboard
    When evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_ami_id` is stored in the :default_ami_id clipboard
    And evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_availability_zone` is stored in the :default_availability_zone clipboard
    And evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_iamInstanceProfile` is stored in the :default_iamInstanceProfile clipboard
    And evaluation of `machine_set_machine_openshift_io(cb.machineset).aws_machineset_subnet_proxy` is stored in the :default_subnet clipboard
    Then admin ensures "<name>" machine_set_machine_openshift_io is deleted after scenario

    Given I obtain test data file "cloud/ms-aws/proxy-clusters/<file_name>"
    When I run oc create over "<file_name>" replacing paths:
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-cluster"]           | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["iamInstanceProfile"]["id"]         | <%= cb.default_iamInstanceProfile %>        |
      | ["spec"]["selector"]["matchLabels"]["machine.openshift.io/cluster-api-machineset"]        | <name>                                      |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-cluster"]    | <%= infrastructure("cluster").infra_name %> |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["ami"]["id"]                        | <%= cb.default_ami_id %>                    |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["placement"]["availabilityZone"]    | <%= cb.default_availability_zone %>         |
      | ["spec"]["template"]["spec"]["providerSpec"]["value"]["subnet"]["id"]                     | <%= cb.default_subnet %>                    |
      | ["spec"]["template"]["metadata"]["labels"]["machine.openshift.io/cluster-api-machineset"] | <name>                                      |
      | ["metadata"]["name"]                                                                      | <name>                                      |
    Then the step should succeed

    Then I store the last provisioned machine in the :machine_latest clipboard
    And I wait up to 540 seconds for the steps to pass:
    """
    Then the expression should be true> machine_machine_openshift_io(cb.machine_latest).phase(cached: false) == "Running"
    """

    When I run the :describe admin command with:
      | resource | machines.machine.openshift.io |
      | name     | <%= cb.machine_latest %>      |
    Then the step should succeed
    And the output should contain:
      | <Validation> |

    @aws-ipi
    @proxy @disconnected
    @network-ovnkubernetes @network-openshiftsdn
    @heterogeneous @arm64 @amd64
    @hypershift-hosted
    Examples:
      | case_id                         | name                    | file_name                 | Validation                    |
      | OCP-48463:ClusterInfrastructure | default-valued-48463    | ms_default_values.yaml    | Placement                     | # @case_id OCP-48463
      | OCP-48464:ClusterInfrastructure | tenancy-dedicated-48464 | ms_tenancy_dedicated.yaml | Tenancy:            dedicated | # @case_id OCP-48464
      | OCP-48462:ClusterInfrastructure | default-valued-48462    | ms_default_values.yaml    | Instance Type:  m5.large      | # @case_id OCP-48462

