 Feature: SDN multus compoment upgrade testing
 
  # @author weliang@redhat.com
  @admin
  @upgrade-prepare
  Scenario: Check the multus works well after upgrade - prepare
    Given the multus is enabled on the cluster
    Given the default interface on nodes is stored in the :default_interface clipboard
    # Create the net-attach-def via cluster admin
    Given I switch to cluster admin pseudo user
    When I run the :new_project client command with:
      | project_name | multus-upgrade |
    Then the step should succeed
    When I use the "multus-upgrade" project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/whereabouts-macvlan.yaml"
    When I run oc create as admin over "whereabouts-macvlan.yaml" replacing paths:
      | ["metadata"]["namespace"] | <%= project.name %>                                                                                                                                                      |
      | ["spec"]["config"]        | '{ "cniVersion": "0.3.1", "type": "macvlan", "master": "<%= cb.default_interface %>","mode": "bridge", "ipam": { "type": "whereabouts", "range": "192.168.22.100/30"} }' |
    Then the step should succeed

    # Create a pod absorbing above net-attach-def
    Given I obtain test data file "networking/multus-cni/Pods/generic_multus_pod_upgrade.yaml"
    When I run oc create over "generic_multus_pod_upgrade.yaml" replacing paths:
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"]                             | test-pod1                       |
      | ["items"][0]["metadata"]["name"]                                                           | macvlan-bridge-whereabouts-pod1 |
      | ["items"][0]["spec"]["template"]["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | macvlan-bridge-whereabouts      |
      | ["items"][0]["spec"]["template"]["spec"]["containers"][0]["name"]                          | macvlan-bridge-whereabouts      |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pod1 |

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
      | 192.168.22.101 |

  # @author weliang@redhat.com
  # @case_id OCP-44898
  @admin
  @upgrade-check
  Scenario: Check the multus works well after upgrade
    Given I switch to cluster admin pseudo user
    When I use the "multus-upgrade" project
    Given a pod becomes ready with labels:
      | name=test-pod1 |
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
      | 192.168.22.101 |
    
    # Delete the created project from testing cluster
    Given the "multus-upgrade" project is deleted
