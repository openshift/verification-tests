Feature: Check status via oc status, wait etc

  # @author yapei@redhat.com
  # @case_id OCP-11147
  Scenario: OCP-11147 Show RC info and indicate bad secrets reference in 'oc status'
    Given I have a project

    # Check standalone RC info is dispalyed in oc status output
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cli/standalone-rc.yaml |
    Then the step should succeed
    And evaluation of `"stdalonerc"` is stored in the :stdrc_name clipboard
    When I run the :status client command
    Then the step should succeed
    Then the output should match:
      | rc/<%= cb.stdrc_name %> runs openshift/origin |
      | rc/<%= cb.stdrc_name %> created               |
      | \\d warning.*oc status.* to see details       |
    When I run the :status client command with:
      | suggest |     |
    Then the step should succeed
    Then the output should match:
      | rc/<%= cb.stdrc_name %> is attempting to mount a missing secret secret/<%= cb.mysecret_name %> |
    # Clear out memory and cpu usage to fit into online quota limits
    Given I ensure "<%= cb.stdrc_name %>" rc is deleted

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
    Then the step should succeed
    When I run the :status client command
    Then the step should succeed
    And the output should contain:
      | pod/hello-openshift runs aosqe/hello-openshift |
    # Clear out memory and cpu usage to fit into online quota limits
    And I ensure "hello-openshift" pod is deleted

    # Check DC,RC info when has missing/bad secret reference
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cli/application-template-stibuild-with-mount-secret.json |
    Then the step should succeed
    And evaluation of `"my-secret"` is stored in the :missingscrt_name clipboard
    When I create a new application with:
      | template | ruby-helloworld-sample |
    # TODO: yapei, this is a work around for AEP, please add step `the step should succeed` according to latest good solution
    Then I wait for the "database" service to be created
    When I run the :status client command with:
      | suggest |     |
    Then the step should succeed
    And the output should match:
      | dc/frontend is attempting to mount a missing secret secret/<%= cb.missingscrt_name %> |

    # Show RCs for services in oc status
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/cli/replication-controller-match-a-service.yaml |
    Then the step should succeed
    And evaluation of `"rcmatchse"` is stored in the :matchrc_name clipboard
    Then I run the :describe client command with:
      | resource | rc        |
      | name     | rcmatchse |
    Then the step should succeed
    And the output should match:
      | Selector:\\s+name=database |
    When I run the :status client command with:
      | suggest |     |
    Then the step should succeed
    Then the output should match:
      | svc/database                      |
      | dc/database deploys               |
      | rc/<%= cb.matchrc_name %> runs    |
      | rc/<%= cb.matchrc_name %> created |
      | svc/frontend                      |

