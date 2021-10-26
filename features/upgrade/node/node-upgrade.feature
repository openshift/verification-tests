Feature: Node components upgrade tests
  # @author minmli@redhat.com
  @upgrade-prepare
  @admin
  @4.10 @4.9
  Scenario: Make sure nodeConfig is not changed after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :label admin command with:
      | resource | machineconfigpool         |
      | name     | master                    |
      | key_val  | custom-kubelet=small-pods |
    Then the step should succeed
    Given I obtain test data file "customresource/custom_kubelet.yaml"
    When I run the :create client command with:
      | f | custom_kubelet.yaml |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | machineconfigpool |
      | resource_name | master            |
    Then the output should match:
      | .*False\\s+True\\s+False |
    """
    And I wait up to 1980 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource      | machineconfigpool |
      | resource_name | master            |
    Then the output should match:
      | .*True\\s+False\\s+False |
    """
    Given I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    When I run commands on the host:
      | cat /etc/kubernetes/kubelet.conf |
    Then the step should succeed
    And the output should contain:
      | "imageMinimumGCAge": "5m0s"       |
      | "imageGCHighThresholdPercent": 80 |
      | "maxPods": 240                    |

  # @author minmli@redhat.com
  # @case_id OCP-13022
  @upgrade-check
  @admin
  @4.10 @4.9
  @aws-ipi
  Scenario: Make sure nodeConfig is not changed after upgrade
    Given I switch to cluster admin pseudo user
    When I run the :get admin command with:
      | resource      | kubeletconfig  |
      | resource_name | custom-kubelet |
    Then the step should succeed
    And the output should contain:
      | custom-kubelet |
    Given I store the masters in the :masters clipboard
    And I use the "<%= cb.masters[0].name %>" node
    When I run commands on the host:
      | cat /etc/kubernetes/kubelet.conf |
    Then the step should succeed
    And the output should contain:
      | "imageMinimumGCAge": "5m0s"       |
      | "imageGCHighThresholdPercent": 80 |
      | "maxPods": 240                    |

