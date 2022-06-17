Feature: project permissions

  # @author pruan@redhat.com
  # @case_id OCP-11717
  @admin
  Scenario: OCP-11717 Pod creation should fail when pod's node selector conflicts with project node selector
    Given a 5 characters random string of type :dns is stored into the :proj_name clipboard
    When I run the :oadm_new_project admin command with:
      | project_name  | <%= cb.proj_name %> |
      | node_selector | region=west         |
      | admin         | <%= user.name %>    |
    Then the step should succeed
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/selector-east.json |
      | n | <%= cb.proj_name %> |
    Then the step should fail
    And the output should match:
      | pod node label selector conflicts with its project node label selector |

  # @author yinzhou@redhat.com
  # @case_id OCP-10736
  @admin
  Scenario: OCP-10736 The job and HPA should be deleted when project has been deleted
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/hpa/hpa.yaml |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/job/job.yaml |
    Then the step should succeed
    Given evaluation of `project.name` is stored in the :saved_name clipboard
    When I delete the project
    Then the step should succeed
    Given I switch to cluster admin pseudo user
    # Sometimes the project is Terminating when checked by cluster-admin, so need wait.
    And I wait for the resource "project" named "<%= cb.saved_name %>" to disappear
    When I run the :get client command with:
      | resource      | hpa                  |
      | resource_name | php-apache           |
      | n             | <%= cb.saved_name %> |
    Then the step should fail
    Then the output should contain:
      | not found |
    When I run the :get client command with:
      | resource      | job                 |
      | resource_name | pi                  |
      | n             | <%= cb.saved_name %> |
    Then the step should fail
    Then the output should contain:
      | not found |

