Feature: test nodes relates steps

  @admin
  @destructive
  Scenario: nodes test
    Given I have a project
    Given I store the schedulable nodes in the clipboard
    And evaluation of `node.labels` is stored in the :labels_before clipboard
    When label "testme=go" is added to the "<%= cb.nodes.sample.name %>" node
    When label "testme=go" is added to the "<%= cb.nodes.sample.name %>" node
    Then I do nothing
    And evaluation of `node.labels` is stored in the :labels_after clipboard
    Then the expression should be true> !cb.labels_before.keys.include? 'testme'
    Then the expression should be true> cb.labels_after['testme'] == 'go'
    Then the expression should be true> project.labels.nil?

  @admin
  Scenario: fips test
    Given fips is disabled
    Given fips is enabled

  @admin
  Scenario: test fix of "PodSecurity violation error" in 4.12
    Given I select a random node's host
    When I run commands on the host:
      | df -h / |
    Then the step should succeed
