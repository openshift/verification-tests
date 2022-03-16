Feature: PTP related scenarios

  # @author huirwang@redhat.com
  # @case_id OCP-25940
  @admin
  @stage-only
  @4.10 @4.9 @4.6
  Scenario: ptp operator can be deployed successfully
    Given I switch to cluster admin pseudo user
    And I use the "openshift-ptp" project
    #check ptp related pods are ready in openshift-ptp projects
    And all existing pods are ready with labels:
      | app=linuxptp-daemon |
    And status becomes :running of exactly 1 pods labeled:
      | name=ptp-operator |

  # @author huirwang@redhat.com
  # @case_id OCP-25738
  @admin
  @destructive
  Scenario: Linuxptp run as slave can sync to master
    Given the ptp operator is running well
    Given I switch to the first user
    Given I store the nodes in the clipboard
    Given I obtain test data file "networking/ptp/ptp_master.yaml"
    When I run oc create as admin over "ptp_master.yaml" replacing paths:
      | ["spec"]["recommend"][0]["match"][0]["nodeName"] | <%= cb.nodes[0].name %> |
    Then the step should succeed
    Given I register clean-up steps:
    """
    When I run the :delete admin command with:
      | object_type        | PtpConfig     |
      | object_name_or_id  | --all         |
      | n                  | openshift-ptp |
    Then the step should succeed
    """
    Given I obtain test data file "networking/ptp/ptp_slave.yaml"
    When I run oc create as admin over "ptp_slave.yaml" replacing paths:
      | ["spec"]["recommend"][0]["match"][0]["nodeName"] | <%= cb.nodes[1].name %> |
    Then the step should succeed

    And I wait up to 120 seconds for the steps to pass:
    """
    And I get the ptp logs of the "<%= cb.nodes[0].name %>" node since "120s" ago
    And the output should match:
      | selected local clock (.*) as best master |
    And I get the ptp logs of the "<%= cb.nodes[1].name %>" node since "120s" ago
    And the output should contain "CLOCK_REALTIME rms"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-25740
  @admin
  @destructive
  Scenario: Linuxptp runs in transparent udp4 mode
    Given the ptp operator is running well
    Given I switch to the first user
    And I store the nodes in the clipboard
    Given I obtain test data file "networking/ptp/ptp_master.yaml"
    When I run oc create as admin over "ptp_master.yaml" replacing paths:
      | ["spec"]["recommend"][0]["match"][0]["nodeName"] | <%= cb.nodes[0].name %> |
      | ["spec"]["profile"][0]["ptp4lOpts"]              | "-4"                    |
    Then the step should succeed
    Given I register clean-up steps:
    """
    When I run the :delete admin command with:
      | object_type        | PtpConfig     |
      | object_name_or_id  | --all         |
      | n                  | openshift-ptp |
    Then the step should succeed
    """
    Given I obtain test data file "networking/ptp/ptp_slave.yaml"
    When I run oc create as admin over "ptp_slave.yaml" replacing paths:
      | ["spec"]["recommend"][0]["match"][0]["nodeName"] | <%= cb.nodes[1].name %> |
      | ["spec"]["profile"][0]["ptp4lOpts"]              | "-s -4"                 |
    Then the step should succeed

    And I wait up to 120 seconds for the steps to pass:
    """
    And I get the ptp logs of the "<%= cb.nodes[0].name %>" node since "120s" ago
    And the output should match:
      | selected local clock (.*) as best master |
      | Ptp4lOpts: -4 -m --summary_interval 1    |
   And I get the ptp logs of the "<%= cb.nodes[1].name %>" node since "120s" ago
   And the output should contain:
     | CLOCK_REALTIME rms                       |
     | Ptp4lOpts: -s -4 -m --summary_interval 1 |
   """

  # @author huirwang@redhat.com
  # @case_id OCP-26187
  @admin
  @destructive
  @4.10 @4.9
  Scenario: PTP operator starts linuxptp daemon based on nodeSelector configured in default PtpOperatorConfig CRD
    Given the ptp operator is running well
    And I use the "openshift-ptp" project
    Given as admin I successfully merge patch resource "ptpoperatorconfigs.ptp.openshift.io/default" with:
      | {"spec":{"daemonNodeSelector":{"feature.node.kubernetes.io/ptp-capable":"true"}}} |
    Given I register clean-up steps:
    """
    Given as admin I successfully merge patch resource "ptpoperatorconfigs.ptp.openshift.io/default" with:
      | {"spec":{"daemonNodeSelector":{"feature.node.kubernetes.io/ptp-capable":null}}} |
    """

    Given I store the nodes in the clipboard
    Then label "feature.node.kubernetes.io/ptp-capable=true" is added to the "<%= cb.nodes[0].name %>" node
    Given status becomes :running of exactly 1 pods labeled:
      | app=linuxptp-daemon |
    When I run the :get admin command with:
      | resource      | pod                                   |
      | fieldSelector | spec.nodeName=<%= cb.nodes[0].name %> |
      | n             | openshift-ptp                         |
    Then the step should succeed
    And the output should contain "Running"
