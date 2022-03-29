Feature: oc_secrets.feature

  # @author cryan@redhat.com
  # @case_id OCP-12600
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  Scenario: Add secrets to serviceaccount via oc secrets add
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

  # @author xiaocwan@redhat.com
  # @case_id OCP-10631
  @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  Scenario: [origin_platformexp_391] Project admin can process local directory or files and convert it to kubernetes secret
    Given I have a project
    When the "tmpfoo" file is created with the following lines:
      | somecontent |
    And  the "tmpbar" file is created with the following lines:
      | somecontent |
    Then the step should succeed
    When I run the :create_secret client command with:
      | secret_type | generic              |
      | name        | <%= project.name %>1 |
      | from_file   |  tmpfoo              |
      | from_file   |  tmpbar              |
      | n           | <%= project.name %>  |
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
    When I run the :create_secret client command with:
      | secret_type | generic              |
      | name        | <%= project.name %>2 |
      | from_file   |  tmpfoler1           |
      | from_file   |  tmpfoler2           |
      | n           | <%= project.name %>  |
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
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @network-ovnkubernetes
  Scenario: Check name requirements for oc secret
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
