Feature: Node components upgrade tests
  # @author minmli@redhat.com
  @upgrade-prepare
  @admin
  Scenario: Make sure nodeConfig is not changed after upgrade - prepare
    Given I switch to cluster admin pseudo user
    When I run the :label admin command with:
      | resource | machineconfigpool         |
      | name     | master                    |
      | key_val  | custom-kubelet=small-pods |
    Then the step should succeed
    When I run the :create client command with:
      | f | <%= BushSlicer::HOME %>/testdata/customresource/custom_kubelet.yaml |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | machineconfigpool |
    Then the output should match:
      | master.*False\\s+True\\s+False |
    """
    And I wait up to 1200 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | machineconfigpool |
    Then the output should match:
      | master.*True\\s+False\\s+False |
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

