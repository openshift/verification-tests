Feature: ONLY ONLINE Infra related scripts in this file

  # @author etrott@redhat.com
  # @case_id OCP-10142
  Scenario: OCP-10142 User cannot deploy a pod to an infra node
    Given I have a project
    Given I obtain test data file "pods/ocp10142/pod_nodeSelector_infra.yaml"
    When I run the :create client command with:
      | f | pod_nodeSelector_infra.yaml |
    Then the step should fail
    And the output should contain:
      | pod node label selector conflicts with its project node label selector |

  # @author bingli@redhat.com
  # @case_id OCP-11230
  Scenario: OCP-11230 Specify runtime duration of run-once pods globally in master config
    Given I have a project
    When I run the :run client command with:
      | name    | run-once-pod     |
      | image   | openshift/origin |
      | command | true             |
      | cmd     | sleep            |
      | cmd     | 10m              |
      | restart | Never            |
    And the pod named "run-once-pod" status becomes :running
    Then I run the :get client command with:
      | resource      | pod          |
      | resource_name | run-once-pod |
      | o             | yaml         |
    Then the output should contain:
      | activeDeadlineSeconds: 3600 |
    And I delete all resources from the project
    When I create a new application with:
      | template | rails-pgsql-persistent |
    Then the step should succeed
    And the pod named "postgresql-1-deploy" status becomes :running
    Then I run the :get client command with:
      | resource      | pod                 |
      | resource_name | postgresql-1-deploy |
      | o             | yaml                |
    Then the output should contain:
      | activeDeadlineSeconds: 3600 |
    And the pod named "rails-pgsql-persistent-1-build" status becomes :running
    Then I run the :get client command with:
      | resource      | pod                            |
      | resource_name | rails-pgsql-persistent-1-build |
      | o             | yaml                           |
    Then the output should contain:
      | activeDeadlineSeconds: 3600 |

