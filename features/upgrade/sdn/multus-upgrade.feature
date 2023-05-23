 Feature: SDN multus compoment upgrade testing

  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  @4.13 @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @hypershift-hosted
  Scenario: Check the multus works well after upgrade - prepare
    Given the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    # Create the net-attach-def via cluster admin
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | multus-upgrade |
    Then the step should succeed
    And the appropriate pod security labels are applied to the "multus-upgrade" namespace
    When I use the "multus-upgrade" project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/ipam-static.yaml"
    When I run oc create as admin over "ipam-static.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                      |
      | ["metadata"]["name"]      | bridge-static                                                                                                                            |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "bridge", "ipam": {"type":"static","addresses": [{"address": "22.2.2.22/24","gateway": "22.2.2.1"}]}}' |
    Then the step should succeed
    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod_upgrade.yaml"
    When I run oc create over "generic_multus_pod_upgrade.yaml" replacing paths:
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"]                             | bridge-static-pod1 |
      | ["items"][0]["metadata"]["name"]                                                           | bridge-static-pod1 |
      | ["items"][0]["spec"]["template"]["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | bridge-static      |
      | ["items"][0]["spec"]["template"]["spec"]["containers"][0]["name"]                          | bridge-static      |
    Then the step should succeed
    Given a pod becomes ready with labels:
    | name=bridge-static-pod1 |

    # Check created pod has correct ip address on interface net1
    When I execute on the pod:
      | ip | a |
    Then the output should match:
      | 22.2.2.22 |

  # @author weliang@redhat.com
  # @case_id OCP-44898
  @admin
  @upgrade-check
  @4.13 @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @hypershift-hosted
  Scenario: Check the multus works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "multus-upgrade" project
    Given a pod becomes ready with labels:
      | name=bridge-static-pod1 |
    # Check created pod has correct ip address on interface net1
    When I execute on the pod:
      | ip | a |
    Then the output should match:
      | 22.2.2.22 |

