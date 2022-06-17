Feature: test master config related steps

  # @author chezhang@redhat.com
  # @case_id OCP-10619
  @admin
  @destructive
  Scenario: OCP-10619 defaultNodeSelector options on master will make pod landing on nodes with label "infra=false"
    Given master config is merged with the following hash:
    """
    projectConfig:
      defaultNodeSelector: "infra=test"
      projectRequestMessage: ""
      projectRequestTemplate: ""
      securityAllocator:
        mcsAllocatorRange: "s0:/2"
        mcsLabelsPerProject: 5
        uidAllocatorRange: "1000000000-1999999999/10000"
    """
    And the master service is restarted on all master nodes
    Given I have a project
    Given I run the :patch admin command with:
      | resource | namespace |
      | resource_name | <%=project.name%> |
      | p | {"metadata":{"annotations": {"openshift.io/node-selector": ""}}}|
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
    Then the step should succeed
    And the pod named "hello-openshift" status becomes :pending
    Given I store the schedulable nodes in the :nodes clipboard
    When label "infra=test" is added to the "<%= cb.nodes[0].name %>" node
    Then the pod named "hello-openshift" status becomes :running
    Given I ensure "hello-openshift" pod is deleted
    And label "infra-" is added to the "<%= cb.nodes[0].name %>" node
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    When I run the :oadm_new_project admin command with:
      | project_name  | <%= cb.proj_name %>       |
      | node_selector | <%= cb.proj_name %>=hello |
      | admin         | <%= user.name %>          |
    Then the step should succeed
    Given I use the "<%= cb.proj_name %>" project
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json |
      | n | <%= cb.proj_name %>                                                                               |
    Then the step should succeed
    And the pod named "hello-openshift" status becomes :pending
    When label "<%= cb.proj_name %>=hello" is added to the "<%= cb.nodes[0].name %>" node
    Then the pod named "hello-openshift" status becomes :running

  # @author chezhang@redhat.com
  # @case_id OCP-13557
  @admin
  @destructive
  Scenario: OCP-13557 NodeController will sets NodeTaints when node become notReady/unreachable
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

