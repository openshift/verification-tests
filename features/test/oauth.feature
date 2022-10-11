Feature: oauth related

  @admin
  Scenario: test oauth supports
    Given I switch to cluster admin pseudo user
    And the secret for "foobar" htpasswd is stored in the clipboard
