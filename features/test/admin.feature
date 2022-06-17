Feature: Testing Admin Scenarios

  @admin
  Scenario: simple create project admin scenario
    When I run the :oadm_new_project admin command with:
      | project_name | demo                                             |
      | display name | OpenShift 3 Demo                                 |
      | description  | This is the first demo project with OpenShift v3 |
      | admin        | <%= user.name %>                                 |
    Then the step should succeed
    When I run the :get client command with:
      | resource | projects |
    Then the step should succeed
    And the output should contain:
      | OpenShift 3 Demo |
      | Active |

  @admin
  Scenario: exec in defailt repo pod
    Given I switch to cluster admin pseudo user
    And I use the "default" project
    And a pod becomes ready with labels:
      | docker-registry=default |
    When I execute on the pod:
      | find            |
      | /registry       |
      | -type           |
      | f               |
    Then the step should succeed
    And the output should contain:
      |blobs/sha|

  # @author yinzhou@redhat.com
  # @case_id OCP-9748
  @admin
  Scenario: OCP-9748 Use options minify/raw/flatten to check the output of kubeconfig setting
    When I run the :oadm_config_view admin command with:
      | flatten | |
    Then the step should succeed
    And the output should not contain:
      | REDACTED |
    When I run the :oadm_config_view admin command with:
      | raw | |
    Then the step should succeed
    And the output should not contain:
      | REDACTED |
    When I run the :oadm_config_view admin command with:
      | minify | |
    Then the step should succeed
    And the output should contain:
      | REDACTED |

  @admin
  Scenario: test registry restoration
    Given default docker-registry deployment config is restored after scenario

  @admin
  Scenario: admin use the specific project
    Given I have a project
    Given admin uses the "<%= project.name %>" project
    When I run oc create as admin over ERB URL: https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/limits/tc508038/limit.yaml
    Then the step should succeed

  @admin
  Scenario: get rpm information from puddle
    Given I save the rpm name matching /openshift-ansible/ from puddle to the :playbook_rpm_name clipboard
    And I download a file from "<%= cb.puddle_url + "/Packages/" + cb.playbook_rpm_name.first %>"
    Then the step should succeed

  @admin
  Scenario: test ParseConfig gem to parse ini files
    Given I save installation inventory from master to the clipboard
    And evaluation of `cb[:installation_inventory]['OSEv3:vars']` is stored in the :vars clipboard
    Then the expression should be true> cb[:installation_inventory]['OSEv3:vars'].keys == cb.vars.keys
