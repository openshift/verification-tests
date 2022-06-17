Feature: oc_secrets.feature

  # @author cryan@redhat.com
  # @case_id OCP-12600
  Scenario: OCP-12600 Add secrets to serviceaccount via oc secrets add
    Given I have a project
    When I run the :secrets client command with:
      | action | new        |
      | name   | test       |
      | source | /etc/hosts |
    Then the step should succeed
    When I run the :secrets client command with:
      | action         | add                    |
      | serviceaccount | serviceaccount/default |
      | secrets_name   | secret/test            |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | serviceaccount |
      | name     | default        |
    Then the step should succeed
    And the output should contain:
      |Mountable secrets|
      |test|
    When I run the :secrets client command with:
      | action         | add                    |
      | serviceaccount | serviceaccount/default |
      | secrets_name   | secret/test            |
      | for            | pull                   |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | serviceaccount |
      | resource_name | default        |
      | o             | json           |
    Then the step should succeed
    And the output should contain:
      |"imagePullSecrets"|
      |"name": "test"    |
    When I run the :secrets client command with:
      | action         | add                    |
      | serviceaccount | serviceaccount/default |
      | secrets_name   | secret/test            |
      | for            | pull,mount             |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | serviceaccount |
      | resource_name | default        |
      | o             | json           |
    Then the step should succeed
    And the output should contain:
      |"imagePullSecrets"|
    And the output should contain 2 times:
      |"name": "test" |

  # @author qwang@redhat.com
  # @case_id OCP-12244
  @smoke
  Scenario: OCP-12244 CRUD operations on secrets
    Given I have a project
    # 1.1 Create a secret with a non-existing namespace
    When I run the :create client command with:
      | filename  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483168/second-secret.json |
      | namespace | non483167 |
    Then the step should fail
    And the output should match "cannot create secrets in (project|the namespace "non483167").*"
    # 1.2 Create a secret with a correct namespace
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/secrets/tc483168/second-secret.json |
    Then the step should succeed
    # 2. Describe a secret
    When I run the :describe client command with:
      | resource | secret        |
      | name     | second-secret |
    Then the output should match:
      | password:\s+16 bytes |
      | username:\s+16 bytes |
    # 3.1 Update a secret with a invalid namespace
    When I run the :patch client command with:
      | resource      | secret                                    |
      | resource_name | second-secret                             |
      | p             | {"metadata": {"namespace": "secrettest"}} |
    Then the step should fail
    And the output should contain "does not match the namespace"
    # 3.2 Update a secret with a invalid resource
    When I run the :patch client command with:
      | resource      | secret                               |
      | resource_name | second-secret                        |
      | p             | {"metadata": {"name": "testsecret"}} |
    Then the step should fail
    And the output should contain "the name of the object (testsecret) does not match the name on the URL (second-secret)"
    # 3.3 Update a secret with a invalid content
    When I run the :patch client command with:
      | resource      | secret                        |
      | resource_name | second-secret                 |
      | p             | {"data": {"username": "123"}} |
    Then the step should fail
    And the output should contain "illegal base64 data at input byte 0"
    # 3.4 Update a secret with a correct update object
    When I run the :patch client command with:
      | resource      | secret                             |
      | resource_name | second-secret                      |
      | p             | {"data": {"password": "dGVzdA=="}} |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret        |
      | name     | second-secret |
    Then the output should match:
      | password:\s+4 bytes |
      | username:\s+16 bytes |
    # 4. Delete a secret
    When I run the :delete client command with:
      | object_type       | secret   |
      | object_name_or_id | second-secret |
    Then the step should succeed
    # 5. List secrets
    When I run the :get client command with:
      | resource | secret |
    Then the step should succeed
    And the output should not contain "second-secret"

  # @author xiaocwan@redhat.com
  # @case_id OCP-10631
  Scenario: [origin_platformexp_391] Project admin can process local directory or files and convert it to kubernetes secret
    Given I have a project
    When the "tmpfoo" file is created with the following lines:
      | somecontent |
    And  the "tmpbar" file is created with the following lines:
      | somecontent |
    Then the step should succeed
    When I run the :secrets client command with:
      | action | new                  |
      | name   | <%= project.name %>1 |
      | source | tmpfoo               |
      | source | tmpbar               |
      | n      | <%= project.name %>  |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret               |
      | name     | <%= project.name %>1 |
      | n        | <%= project.name %>  |
    Then the step should succeed
    And the output should contain:
      | tmpfoo |
      | tmpbar |

    When the "tmpfoler1/tmpfile1" file is created with the following lines:
      | somecontent |
    And the "tmpfoler2/tmpfile2" file is created with the following lines:
      | somecontent |
    Then the step should succeed
    When I run the :secrets client command with:
      | action | new                  |
      | name   | <%= project.name %>2 |
      | source | tmpfoler1            |
      | source | tmpfoler2            |
      | n      | <%= project.name %>  |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | secret               |
      | name     | <%= project.name %>2 |
      | n        | <%= project.name %>  |
    Then the step should succeed
    And the output should contain:
      | tmpfile1 |
      | tmpfile2 |

  # @author xxia@redhat.com
  # @case_id OCP-11900
  Scenario: OCP-11900 Check name requirements for oc secret
    Given I have a project
    And I run the :get client command with:
      | resource      | project |
      | resource_name | <%= project.name %> |
      | o             | json    |
    Then the step should succeed
    # Prepare filenames
    Then I save the output to file> file-1234567890.com.json
    And I save the output to file> file.json
    And I save the output to file> file!@#$.json

    When I run the :secrets client command with:
      | action | new           |
      | name   | mysecret1     |
      | source | file!@#$.json |
    Then the step should fail
    And the output should match:
      | [Ee]rror |
      | valid |

    When I run the :secrets client command with:
      | action | new           |
      | name   | mysecret1     |
      | source | file-1234567890.com.json |
    Then the step should succeed

    When I run the :secrets client command with:
      | action | new           |
      | name   | mysecret!@#$  |
      | source | file.json |
    Then the step should fail
    And the output should match:
      | [Ii]nvalid     |

    When I run the :secrets client command with:
      | action | new       |
      | name   | mysecret-1234567890.com  |
      | source | file.json |
    Then the step should succeed

    # Same filenames
    When I run the :secrets client command with:
      | action | new       |
      | name   | mysecret2 |
      | source | file.json |
      | source | file.json |
    Then the step should fail
    And the output should match:
      | cannot add key file.json.*another key by that name already exist |

  # @author wjiang@redhat.com
  # @case_id OCP-11482
  Scenario: OCP-11482 Bundle secret will not load subdir and warning message will be displayed when -q is not present
    Given I have a project
    Given a "first/second/test" file is created with the following lines:
      |second test|
    Given a "first/test" file is created with the following lines:
      |first test|
    When I run the :new_secret client command with:
      | secret_name     | mysecret|
      | credential_file | first   |
    Then the step should succeed
    Then the output should contain:
      | Skipping resource first/second |
    When I run the :new_secret client command with:
      | secret_name     | mysecret1 |
      | credential_file | first     |
      | quiet   | true      |
    Then the step should succeed
    Then the output should not contain:
      | Skipping resource first/second |

