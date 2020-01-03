Feature: Egress IP related features

  # @author bmeng@redhat.com
  # @case_id OCP-15465
  @admin
  Scenario: Only cluster admin can add/remove egressIPs on hostsubnet
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard

    # Try to add the egress ip to the hostsubnet with normal user
    When I run the :patch client command with:
      | resource      | hostsubnet |
      | resource_name | <%= cb.egress_node %> |
      | p             | {"egressIPs":["<%= cb.valid_ip %>"]} |
    Then the step should fail
    And the output should contain "Forbidden"

  # @author bmeng@redhat.com
  # @case_id OCP-15466
  Scenario: Only cluster admin can add/remove egressIPs on netnamespaces
    # Try to add the egress ip to the netnamespace with normal user
    Given I have a project
    And evaluation of `project.name` is stored in the :project clipboard
    When I run the :patch client command with:
      | resource      | netnamespace |
      | resource_name | <%= cb.project %> |
      | p             | {"egressIPs":["<%= cb.valid_ip %>"]} |
    Then the step should fail
    And the output should contain "Forbidden"

  # @author bmeng@redhat.com
  # @case_id OCP-15471
  @admin
  Scenario: All the pods egress connection will get out through the egress IP if the egress IP is set to netns and egress node can host the IP
    Given I select a random node's host
    # create project with pods
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard

    # add the egress ip to the hostsubnet
    And the valid egress IP is added to the node

    # add the egress ip to the project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    # create some more pods after the egress ip patched
    When I run the :scale client command with:
      | resource | replicationcontrollers |
      | name     | test-rc                |
      | replicas | 4                      |
    Then the step should succeed
    Given 4 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(2).name` is stored in the :pod3 clipboard
    And evaluation of `pod(3).name` is stored in the :pod4 clipboard

    # try to access the receiver service to get the source IP

    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod2 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod3 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"
    When I execute on the "<%= cb.pod4 %>" pod:
      | curl | -s | --connect-timeout | 5 | ifconfig.me |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-15472
  @admin
  Scenario: The egressIPs will be added to the node's primary NIC when it gets set on hostsubnet and will be removed after gets unset
    # add the egress ip to the hostsubnet
    Given  the valid egress IP is added to the node
    And evaluation of `node.name` is stored in the :egress_node clipboard

    # add the egress ip to the project
    Given I have a project
    Given as admin I successfully merge patch resource "netnamespace/<%= project.name %>" with:
      | {"egressIPs": ["<%= cb.valid_ip %>"]} |

    # check egress ip was added to primary interface
    When I run command on the "<%= cb.egress_node %>" node's sdn pod:
      | bash | -c | ip address show <%= cb.interface %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    # Remove the egress ip from hostsbunet
    Given as admin I successfully merge patch resource "hostsubnet/<%= cb.egress_node %>" with:
      | {"egressIPs": null} |

     # check egress ip was removed from primary interface
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run command on the "<%= cb.egress_node %>" node's sdn pod:
      | bash | -c | ip address show <%= cb.interface %> |
    Then the step should succeed
    And the output should not contain "<%= cb.valid_ip %>"
    """
