Feature: example kata container scenarios

  Scenario: test get channel
    Given I extract the channel information from subscription and save it to the :channel clipboard

  @admin
  Scenario: test kata_step
    Given I have a project
    And I obtain test data file "kata/example-fedora-kata.yaml"
    When I run the :create client command with:
      | f | example-fedora-kata.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=example-fedora-kata-app |
    Given I create a new project
    And I obtain test data file "templates/ui/httpd-example.yaml"
    Then I run the :new_app client command with:
      | file | httpd-example.yaml |
    And a pod becomes ready with labels:
      | name=httpd-example |
    Given I switch to cluster admin pseudo user
    Given I find all pods running with kata as runtime in the cluster and store them to the clipboard
    And I remove all kata pods in the cluster stored in the clipboard
