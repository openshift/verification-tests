Feature: oc_set_build_hook

  # @author cryan@redhat.com
  # @case_id OCP-11602
  # @bug_id 1351797
  @aws-ipi
  @proxy
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @vsphere-upi
  Scenario: Set post-build-commit on buildconfig via oc set build-hook
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift/rails-ex/master/openshift/templates/rails-postgresql.json"
    Then the step should succeed
    #cancel first build to speed up process, as it's irrelevant to the test
    Given the "rails-postgresql-example-1" build was created
    When I run the :cancel_build client command with:
      | build_name | rails-postgresql-example-1 |
    Then the step should succeed
    When I run the :set_build_hook client command with:
      | buildconfig | bc/rails-postgresql-example |
      | post_commit | true                        |
      | command     |                             |
      | oc_opts_end |                             |
      | args        | /bin/bash                   |
      | args        | -c                          |
      | args        | bundle                      |
      | args        | exec                        |
      | args        | rake                        |
      | args        | test                        |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | rails-postgresql-example |
    Then the step should succeed
    Given the "rails-postgresql-example-2" build completes
    When I run the :set_build_hook client command with:
      | buildconfig | bc/rails-postgresql-example |
      | post_commit | true                        |
      | script      | bundle exec rake test       |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | rails-postgresql-example |
    Then the step should succeed
    And the "rails-postgresql-example-3" build completes
