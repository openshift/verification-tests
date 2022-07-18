 Feature: SDN multus compoment upgrade testing

  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  Scenario: Check the multus works well after upgrade - prepare
    Given the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    # Create the net-attach-def via cluster admin
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | multus-upgrade |
    Then the step should succeed
    When I use the "multus-upgrade" project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/ipam-static.yaml"
    When I run oc create as admin over "ipam-static.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                      |
      | ["metadata"]["name"]      | bridge-static                                                                                                                            |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "bridge", "ipam": {"type":"static","addresses": [{"address": "22.2.2.22/24","gateway": "22.2.2.1"}]}}' |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/multus-default-route-pod.yaml"
    When I run the :create client command with:
      | f | multus-default-route-pod.yaml |
      | n | <%= project.name %>           |
    Then the step should succeed
    And the pod named "multus-default-route-pod" becomes ready

    # Check pod1 has correct macvlan mode on interface net1
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain:
      | net1                |
      | macvlan mode bridge |
    # Check created pod has correct ip address on interface net1
    When I execute on the pod:
      | ip | a |
    Then the output should contain:
      | 22.2.2.22 |

  # @author weliang@redhat.com
  # @case_id OCP-44898
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  Scenario: Check the multus works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "multus-upgrade" project
    Given a pod becomes ready with labels:
      | multus-default-route-pod |
    # Check pod1 has correct macvlan mode on interface net1
    When I execute on the pod:
      | ip | -d | link |
    Then the output should contain:
      | net1                |
      | macvlan mode bridge |
    # Check created pod has correct ip address on interface net1
    When I execute on the pod:
      | ip | a |
    Then the output should contain:
      | 22.2.2.22 |

    # Delete the created project from testing cluster
    Given the "multus-upgrade" project is deleted
