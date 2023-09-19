Feature: Operator related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-22704
  @admin
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-22704:SDN The clusteroperator should be able to reflect the network operator version corresponding to the OCP version

    Given the master version > "3.11"
    #Getting OCP version
    Given evaluation of `cluster_version('version').version` is stored in the :ocp_version clipboard
    And evaluation of `cluster_operator('network').condition(type: 'Available')` is stored in the :operator_status clipboard
    #Making sure that network operator AVAILABLE status value is True
    Then the expression should be true> cb.operator_status["status"] == "True"
    #Confirm whether network operator version matches with ocp version
    And the expression should be true> cluster_operator('network').version_exists?(version: cb.ocp_version)

  # @author anusaxen@redhat.com
  # @case_id OCP-22706
  @admin
  @destructive
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @network-openshiftsdn
  @proxy @noproxy
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @hypershift-hosted
  Scenario: OCP-22706:SDN The clusteroperator should be able to reflect the correct version field post bad network operator config

    Given the master version >= "4.1"
    #Getting OCP version
    Given evaluation of `cluster_version('version').version` is stored in the :ocp_version clipboard
    #Making sure that operator is not Degraded before proceesing further steps
    And evaluation of `cluster_operator('network').condition(type: 'Degraded')` is stored in the :degraded_status_before_patch clipboard
    Then the expression should be true> cb.degraded_status_before_patch["status"] == "False"
    #Making sure that operator is not Degraded before proceesing further steps
    And evaluation of `cluster_operator('network').condition(type: 'Degraded')` is stored in the :degraded_status_before_patch clipboard
    Then the expression should be true> cb.degraded_status_before_patch["status"] == "False"
    #Editing networks.config.openshift.io cluster to reflect bad config like changing networktype from OpenShiftSDN to OpenShift
    When I run the :patch admin command with:
      | resource      | networks.config.openshift.io         |
      | resource_name | cluster                              |
      | p             | {"spec":{"networkType":"OpenShift"}} |
      | type          | merge                                |
    Then the step should succeed

    #Registering clean-up steps to move networkType back to OpenShiftSDN and to check Degraded status is False before test exits
    Given I register clean-up steps:
    """
    When I run the :patch admin command with:
      | resource      | networks.config.openshift.io            |
      | resource_name | cluster                                 |
      | p             | {"spec":{"networkType":"OpenShiftSDN"}} |
      | type          | merge                                   |
    Then the step should succeed
    And 20 seconds have passed
    And evaluation of `cluster_operator('network').condition(type: 'Degraded',cached: false)` is stored in the :degraded_status clipboard
    Then the expression should be true> cb.degraded_status["status"] == "False"
    """
    #Normally it takes 5-10 seconds for network config update to reconcile across the cluster but taking 20 seconds wait to make sure that Degraded status becomes True post bad patch
    Given 20 seconds have passed
    And evaluation of `cluster_operator('network').condition(type: 'Degraded',cached: false)` is stored in the :degraded_status_post_patch clipboard
    Then the expression should be true> cb.degraded_status_post_patch["status"]=="True"
    And the expression should be true> cluster_operator('network').version_exists?(version: cb.ocp_version)

  # @author bmeng@redhat.com
  # @case_id OCP-22201
  @admin
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @network-openshiftsdn
  @proxy @noproxy
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-22201:SDN Should have a clusteroperator object created under config.openshift.io api group for network-operator
    Given the master version >= "4.1"
    # Check the operator object has version
    Given the expression should be true> cluster_operator('network').versions.length > 0
    # Check the operator object has status for Degraded|Progressing|Available
    And the expression should be true> cluster_operator('network').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('network').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('network').condition(type: 'Progressing')['status'] == "False"


  # @author bmeng@redhat.com
  # @case_id OCP-22419
  @admin
  @destructive
  Scenario: OCP-22419:SDN The clusteroperator should be able to reflect the realtime status of the network when the config has problem
    Given the master version >= "4.1"
    # Check that the operator is not Degraded
    Given the expression should be true> cluster_operator('network').condition(type: 'Degraded')['status'] == "False"
    # Copy the value of the networktype for backup
    When I run the :get admin command with:
      | resource      | network.config.openshift.io |
      | resource_name | cluster                     |
      | template      | {{.spec.networkType}}       |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :network_type clipboard
    # Do some modification on the network.config.openshift.io
    When I run the :patch admin command with:
      | resource      | network.config.openshift.io     |
      | resource_name | cluster                         |
      | p             | {"spec":{"networkType":"None"}} |
      | type          | merge                           |
    Then the step should succeed
    Given I register clean-up steps:
    """
    When I run the :patch admin command with:
      | resource      | network.config.openshift.io                       |
      | resource_name | cluster                                           |
      | p             | {"spec":{"networkType":"<%= cb.network_type %>"}} |
      | type          | merge                                             |
    Then the step should succeed
    """
    # Check that the operator status reflect the problem
    Given I wait up to 10 seconds for the steps to pass:
    """
    Given the status of condition "Degraded" for network operator is :True
    And the status of condition "Available" for network operator is :True
    """
    # Change the network.config.openshift.io back
    When I run the :patch admin command with:
      | resource      | network.config.openshift.io                       |
      | resource_name | cluster                                           |
      | p             | {"spec":{"networkType":"<%= cb.network_type %>"}} |
      | type          | merge                                             |
    Then the step should succeed
    # Check that the operator status
    Given I wait up to 20 seconds for the steps to pass:
    """
    Given the status of condition "Degraded" for network operator is :False
    And the status of condition "Available" for network operator is :True
    """

  # @author bmeng@redhat.com
  # @author zzhao@redhat.com
  # @case_id OCP-22202
  @admin
  @destructive
  Scenario: OCP-22202:SDN The clusteroperator should be able to reflect the realtime status of the network when a new node added
    Given I have an IPI deployment
    And I switch to cluster admin pseudo user
    And I use the "openshift-machine-api" project
    # Check that the operator is not progressing at the beginning to make sure the network operator is normal
    Given I wait up to 160 seconds for the steps to pass:
    """
    Given the status of condition "Progressing" for network operator is :False
    """

    And admin ensures machine number is restored after scenario
    Given I clone a machineset and name it "machineset-clone-sdn"

    # Check that the status of Progressing is truned to True during the new node provisioning
    Given I wait up to 360 seconds for the steps to pass:
    """
    Given the status of condition "Progressing" for network operator is :True
    """

    And the machineset should have expected number of running machines
    # Check that the status of Progressing is back to False once the node provision finished
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource | node |
    Then the step should succeed
    And the output should not contain "NotReady"
    Given the status of condition "Progressing" for network operator is :False
    """

  # @author anusaxen@redhat.com
  # @case_id OCP-24918
  @flaky
  @admin
  @destructive
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @network-ovnkubernetes @network-openshiftsdn
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-24918:SDN Service should not get unidle when config flag is disabled under CNO
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    And 2 pods become ready with labels:
      | name=test-pods |
    #And evaluation of `pod(0).node_name` is stored in the :node_name clipboard
    And I store "<%= pod(0).node_name %>" node's corresponding default networkType pod name in the :sdn_pod clipboard

    Given I use the "test-service" service
    And evaluation of `service.ip(user: user)` is stored in the :service_ip clipboard
    # Checking idling unidling manually to make sure it works fine before inducing flag feature
    When I run the :idle client command with:
      | svc_name | test-service |
    Then the step should succeed
    And the output should contain:
      | The service "<%= project.name %>/test-service" has been marked as idled |

    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | /usr/bin/curl | --connect-timeout | 60 | <%= cb.service_ip %>:27017 |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |

    #Inducing flag disablement here an polling loop of 300 seconds for CNO to update it across the nodes by checking keywords in sdn logs
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"defaultNetwork":{"openshiftSDNConfig":{"enableUnidling" : false}}}} |
    # Cleanup required to move operator config back to normal
    Given I register clean-up steps:
    """
    as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"defaultNetwork":{"openshiftSDNConfig": null}}} |
    """
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= cb.sdn_pod %> |
      | namespace     | openshift-sdn     |
      | since         | 30s               |
    Then the step should succeed
    And the output should not contain:
      | unidlingProxy |
    """
    And 60 seconds have passed
    #We are idling service again and making sure it doesn't get unidle due to the above enableUnidling flag set to false
    When I run the :idle client command with:
      | svc_name | test-service |
    Then the step should succeed
    And the output should contain:
      | The service "<%= project.name %>/test-service" has been marked as idled |
    When I execute on the "hello-pod" pod:
      | /usr/bin/curl | --connect-timeout | 60 | <%= cb.service_ip %>:27017 |
    Then the step should fail
    #Moving CNO config back to normal and expect service to unidle by polling loop of 300 seconds for CNO by checking keywords in sdn logs
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"defaultNetwork":{"openshiftSDNConfig": null}}} |
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= cb.sdn_pod %> |
      | namespace     | openshift-sdn     |
      | since         | 5s                |
    Then the step should succeed
    And the output should contain:
      | unidlingProxy |
    """
    And 60 seconds have passed
    When I execute on the "hello-pod" pod:
      | /usr/bin/curl | --connect-timeout | 60 | <%= cb.service_ip %>:27017 |
    Then the step should succeed
    And the output should contain:
      | Hello OpenShift |

  # @author anusaxen@redhat.com
  # @case_id OCP-21574
  @admin
  @destructive
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @upgrade-sanity
  @network-openshiftsdn @network-networkpolicy
  @proxy @noproxy
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  @critical
  Scenario: OCP-21574:SDN Should not allow to change the openshift-sdn config
    #Trying to change network mode to Subnet or any other
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec": {"defaultNetwork": {"openshiftSDNConfig": {"mode": "Subnet"}}}} |
    #Cleanup for bringing CRD to original
    Given I register clean-up steps:
    """
    as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec": {"defaultNetwork": {"openshiftSDNConfig": null}}} |
    """
    And 10 seconds have passed
    #Getting network operator pod name to leverage for its logs collection later
    Given I switch to cluster admin pseudo user
    And I use the "openshift-network-operator" project
    When I run the :get client command with:
      | resource | pods                               |
      | o        | jsonpath={.items[*].metadata.name} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :network_operator_pod clipboard
    When I run the :logs client command with:
      | resource_name | <%= cb.network_operator_pod %> |
      | since         | 10s                            |
    Then the step should succeed
    And the output should contain:
      | cannot change openshift-sdn |

  # @author anusaxen@redhat.com
  # @case_id OCP-25856
  @flaky
  @admin
  @destructive
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-25856:SDN CNO should delete non-relevant resources
    # Make sure that the multus is Running
    Given the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    #Patching config in network operator config CRD
    Given as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": [{"name":"bridge-ipam-dhcp","namespace":"openshift-multus","rawCNIConfig":"{\"name\":\"bridge-ipam-dhcp\",\"cniVersion\":\"0.3.1\",\"type\":\"bridge\",\"master\":\"<%= cb.default_interface %>\",\"ipam\":{\"type\": \"dhcp\"}}","type":"Raw"}]}} |
    #Cleanup for bringing CRD to original at the end of this scenario
    Given I register clean-up steps:
    """
    as admin I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": null}} |
    """
    #Make sure dhcp daemon pods spun up after patching the CNO above
    Given I switch to cluster admin pseudo user
    And I wait up to 60 seconds for the steps to pass:
    """
    Given I use the "openshift-multus" project
    And status becomes :running of exactly <%= cb.desired_multus_replicas %> pods labeled:
      | app=dhcp-daemon |
    """
    # Erase additonalnetworks config from CNO and expect dhcp pods to die
    Given I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": null}} |

    And I wait up to 60 seconds for the steps to pass:
    """
    And all existing pods die with labels:
      | app=dhcp-daemon |
    """
    #Patching config in network operator config CRD again for 2nd iteration check
    Given I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": [{"name":"bridge-ipam-dhcp","namespace":"openshift-multus","rawCNIConfig":"{\"name\":\"bridge-ipam-dhcp\",\"cniVersion\":\"0.3.1\",\"type\":\"bridge\",\"master\":\"<%= cb.default_interface %>\",\"ipam\":{\"type\": \"dhcp\"}}","type":"Raw"}]}} |

    # Now scale down CNO pod to 0 and makes sure dhcp pods still running and erase additionalnetworks config from CNO
    Given I use the "openshift-network-operator" project
    And I run the :scale client command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 0                |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given I use the "openshift-network-operator" project
    And I run the :scale client command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 1                |
    Then the step should succeed
    """
    And I wait up to 60 seconds for the steps to pass:
    """
    Given I use the "openshift-multus" project
    #The multus enabled on the cluster step used in beginning stores desired_multus_replicas value in cb variable which is being used here
    And status becomes :running of exactly <%= cb.desired_multus_replicas %> pods labeled:
      | app=dhcp-daemon |
    """
    Given I successfully merge patch resource "networks.operator.openshift.io/cluster" with:
      | {"spec":{"additionalNetworks": null}} |
    # Now scale up CNO pod back to 1 and expect dhcp pods to disappear
    Given I use the "openshift-network-operator" project
    And I run the :scale client command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 1                |
    Then the step should succeed

    And I wait up to 60 seconds for the steps to pass:
    """
    Given I use the "openshift-multus" project
    And all existing pods die with labels:
      | app=dhcp-daemon |
    """

  # @author anusaxen@redhat.com
  # @case_id OCP-27333
  @admin
  @destructive
  @network-ovnkubernetes
  @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: OCP-27333:SDN Changing mtu in CNO should not be allowed
    Given the mtu value "1750" is patched in CNO config according to the networkType
    And admin uses the "openshift-network-operator" project
    When I run the :get admin command with:
      | resource | pods                               |
      | o        | jsonpath={.items[*].metadata.name} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :network_operator_pod clipboard
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= cb.network_operator_pod %> |
      | since         | 30s                            |
    Then the step should succeed
    And the output should contain:
      | cannot change ovn-kubernetes MTU |
    """
