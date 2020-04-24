Feature: test master config related steps
  # @author chezhang@redhat.com
  # @case_id OCP-13557
  @admin
  @destructive
  Scenario: NodeController will sets NodeTaints when node become notReady/unreachable
    Given environment has at least 2 schedulable nodes
    Given master config is merged with the following hash:
    """
    kubernetesMasterConfig:
      controllerArguments:
        feature-gates:
        - TaintBasedEvictions=true
    """
    And the master service is restarted on all master nodes
    Given I have a project
    Given I run the :patch admin command with:
      | resource | namespace |
      | resource_name | <%=project.name%> |
      | p | {"metadata":{"annotations": {"openshift.io/node-selector": ""}}}|
    Then the step should succeed
    Given I store the schedulable nodes in the :nodes clipboard
    Given I use the "<%= cb.nodes[0].name %>" node
    Given the node service is restarted on the host after scenario
    And I register clean-up steps:
    """
    When I run commands on the host:
      | systemctl restart crio \|\| systemctl restart cri-o  \|\| systemctl restart docker |
    Then the step should succeed
    """
    Given I run commands on the host:
      | systemctl stop crio \|\| systemctl stop cri-o \|\| systemctl stop docker |
    Then the step should succeed
    Given I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe admin command with:
      | resource | no                      |
      | name     | <%= cb.nodes[0].name %> |
    Then the output should match:
      | Taints:\\s+node(.alpha)?.kubernetes.io\/not-?[Rr]eady:NoExecute |
    """
    When I run the :get admin command with:
      | resource      | no                      |
      | resource_name | <%= cb.nodes[0].name %> |
      | o             | yaml                    |
    Then the output by order should contain:
      | message: container runtime is down |
      | reason: KubeletNotReady            |
      | status: "False"                    |
      | type: Ready                        |
    Given I use the "<%= cb.nodes[0].name %>" node
    Given I run commands on the host:
      | systemctl start crio \|\| systemctl start cri-o \|\| systemctl start docker |
    Then the step should succeed
    Given I wait for the steps to pass:
    """
    When I run the :describe admin command with:
      | resource | no                      |
      | name     | <%= cb.nodes[0].name %> |
    Then the output should match:
      | Taints:\\s+<none> |
    """
    When I run the :get admin command with:
      | resource      | no                      |
      | resource_name | <%= cb.nodes[0].name %> |
    Then the output should match:
      | <%= cb.nodes[0].name %>\\s+Ready |
    Given I use the "<%= cb.nodes[0].name %>" node
    Given I run commands on the host:
      | systemctl stop atomic-openshift-node |
    Then the step should succeed
    Given I wait for the steps to pass:
    """
    When I run the :describe admin command with:
      | resource | no                      |
      | name     | <%= cb.nodes[0].name %> |
    Then the output should match:
      | Taints:\\s+node(.alpha)?.kubernetes.io\/unreachable:NoExecute |
    """
    When I run the :get admin command with:
      | resource      | no                      |
      | resource_name | <%= cb.nodes[0].name %> |
      | o             | yaml                    |
    Then the output should contain 4 times:
      | message: Kubelet stopped posting node status |
      | reason: NodeStatusUnknown                    |
      | status: Unknown                              |

