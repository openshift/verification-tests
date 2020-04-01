Feature: htpasswd idp feature

  # @author pmali@redhat.com
  # @case_id OCP-23517
  @admin
  @destructive
  Scenario: User can login if and only if user and identity exist and reference to correct user or identity for provision strategy lookup
    Given the user has all owned resources cleaned
    Given the "cluster" oauth CRD is restored after scenario
    Given a "tc509116_htpasswd" file is created with the following lines:
    """
509116_user:$2y$05$YNzkY8fbQrQ650lwfBz8TOrS7cq4xiDpO1tDwSRy980a.fjaaZ5uW
    """
    When I run the :create_secret admin command with:
      | name        | htpass-secret-23517 |
      | secret_type | generic             |
      | from_file   | tc509116_htpasswd            |
      | n           | openshift-config    |
    Then the step should succeed
    And admin ensure "htpass-secret-23517" secret is deleted from the "openshift-config" project after scenario
    When I run the :patch admin command with:
      | resource      | oauth        |
      | resource_name | cluster      |
      | p             | {"spec":{"identityProviders":[{"name":"htpassidp-23517","mappingMethod":"lookup","type":"HTPasswd","htpasswd":{"fileData":{"name":"htpass-secret-23517"}}}]}} |
      | type          | merge        |
    Then the step should succeed
    When I run the :login client command with:
      | server   | <%= env.api_endpoint_url %> |
      | username | 509116_user                 |
      | password | password                    |
    Then the step should fail
    Given I run the :create admin command with:
      | f | https://raw.githubusercontent.com/rhpmali/verification-tests/master/testdata/authorization/idp/tc509116_user.json|
    Then the step should succeed
    And I register clean-up steps:
      """
      Given I run the :delete admin command with:
        | object_type       | user        |
        | object_name_or_id | 509116_user |
      Then the step should succeed
      """
    Given I run the :create admin command with:
      | f | https://raw.githubusercontent.com/rhpmali/verification-tests/master/testdata/authorization/idp/tc509116_identity.json |
    Then the step should succeed
    Given I run the :create admin command with:
      | f | https://raw.githubusercontent.com/rhpmali/verification-tests/master/testdata/authorization/idp/tc509116_useridentitymapping.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource   | projects |
    Then the step should succeed
    When I run the :get admin command with:
     | resource | users                        |
    Then the step should succeed
    And the output should contain:
     | NAME       | 509116_user               |
    Given I run the :delete admin command with:
      | object_type       | identity                |
      | object_name_or_id | htpassidp-23517:509116_user |
    Then the step should succeed
    When I run the :login client command with:
      | server   | <%= env.api_endpoint_url %> |
      | username | 509116_user                 |
      | password | password                    |
    Then the step should fail

