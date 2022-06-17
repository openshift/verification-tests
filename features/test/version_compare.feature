Feature: test version compare

  Scenario: test version compare
    Given the master version >= "3.11"
    Given the master version >= "3.5"
    Given the master version >= "4.0"
