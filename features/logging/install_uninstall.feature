Feature: install and uninstall related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-11061
  @admin
  @destructive
  Scenario: OCP-11061 Deploy logging via Ansible: clean install when OPS cluster is enabled
    Given I create a project with non-leading digit name
    Given the master version >= "3.5"
    And logging service is installed with ansible using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-11061/inventory |
    Given a pod becomes ready with labels:
      | component=es-ops, logging-infra=elasticsearch,provider=openshift |
    Given a pod becomes ready with labels:
      | component=kibana-ops,logging-infra=kibana,provider=openshift   |

  # @author pruan@redhat.com
  # @case_id OCP-12377
  @admin
  @destructive
  Scenario: OCP-12377 Uninstall logging via Ansible
    Given the master version >= "3.5"
    Given I create a project with non-leading digit name
    # the clean up steps registered with the install step will be using uninstall
    And logging service is installed with ansible using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-12377/inventory |

  # @author pruan@redhat.com
  # @case_id OCP-11431
  @admin
  @destructive
  Scenario: OCP-11431 Deploy logging via Ansible - clean install when OPS cluster is not enabled
    Given the master version >= "3.5"
    Given I create a project with non-leading digit name
    Given logging service is installed with ansible using:
      | inventory | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/OCP-11431/inventory |
    And I run the :get client command with:
      | resource | pod                 |
      | n        | <%= project.name %> |
    Then the step should succeed
    And the output should not contain:
      | logging-curator-ops |
      | logging-es-ops      |
      | logging-fluentd-ops |
      | logging-kibana-ops  |

