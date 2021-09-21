Feature: set deployment-hook/build-hook with CLI

  # @author dyan@redhat.com
  # @case_id OCP-11805
  @aws-ipi
  @proxy
  @gcp-upi
  @gcp-ipi
  @4.9
  @aws-upi
  Scenario: Set pre/mid/post deployment hooks on deployment config via oc set deployment-hook
    Given I have a project
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/rails-ex/master/openshift/templates/rails-postgresql.json |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=rails-postgresql-example-1 |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/rails-postgresql-example |
      | pre              |                             |
      | c                | rails-postgresql-example    |
      | e                | FOO1=BAR1                   |
      | failure_policy   | retry                       |
      | oc_opts_end      |                             |
      | args             | /bin/bash                   |
      | args             | -c                          |
      | args             | bundle                      |
      | args             | exec                        |
      | args             | rake                        |
      | args             | db:migrate                  |
    Then the step should succeed
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/rails-postgresql-example |
      | post             |                             |
      | oc_opts_end      |                             |
      | args             | /bin/true                   |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | rails-postgresql-example |
    Then the step should succeed
    And the output should match:
      | [Pp]re-deployment hook    |
      | failure policy: [Rr]etry  |
      | /bin/bash -c bundle exec rake db:migrate |
      | FOO1=BAR1                 |
      | [Pp]ost-deployment hook   |
      | failure policy: [Ii]gnore |
      | /bin/true                 |
    Given I wait until the status of deployment "rails-postgresql-example" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | dc/rails-postgresql-example |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=rails-postgresql-example-2 |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/rails-postgresql-example |
      | pre              |                             |
      | c                | rails-postgresql-example    |
      | failure_policy   | retry                       |
      | oc_opts_end      |                             |
      | args             | ./migrate-database.sh       |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | rails-postgresql-example |
    Then the step should succeed
    And the output should match:
      | [Pp]re-deployment hook   |
      | failure policy: [Rr]etry |
      | ./migrate-database.sh    |
    Given I wait until the status of deployment "rails-postgresql-example" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | dc/rails-postgresql-example |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=rails-postgresql-example-3 |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/rails-postgresql-example |
      | remove           |                             |
      | pre              |                             |
      | post             |                             |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | rails-postgresql-example |
    Then the step should succeed
    And the output should not match:
      | [Pp]re-deployment hook  |
      | [Pp]ost-deployment hook |

  # @author dyan@redhat.com
  # @case_id OCP-11298
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.9
  @aws-upi
  Scenario: Set invalid pre/mid/post deployment hooks on deployment config via oc set deployment-hook
    Given I have a project
    When I run the :new_app client command with:
      | template | rails-postgresql-example |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=rails-postgresql-example-1 |
    When I run the :set_deployment_hook client command with:
      | deploymentconfig | dc/rails-postgresql-example |
      | post             |                             |
      | o                | json                        |
      | oc_opts_end      |                             |
      | args             | /bin/true                   |
    Then the step should succeed
    When I save the output to file> dc.json
    And I run the :set_deployment_hook client command with:
      | mid            |            |
      | f              | dc.json    |
      | failure_policy | abort      |
      | oc_opts_end    |            |
      | args           | /bin/false |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | dc |
      | name     | rails-postgresql-example |
    Then the step should succeed
    And the output should match:
      | [Mm]id-deployment hook   |
      | failure policy: [Aa]bort |
      | /bin/false               |
    Given I wait until the status of deployment "rails-postgresql-example" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | dc/rails-postgresql-example |
    Then the step should succeed
    And I wait until the status of deployment "rails-postgresql-example" becomes :failed

