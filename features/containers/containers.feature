Feature: Container test feature

  # @author cryan@redhat.com
  # @case_id OCP-9863
  # @bug_id 1292666
  @smoke
  Scenario: OCP-9863:Node Setuid binaries shouldn't work inside of a running container
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod-setuid.yaml |
    Then the step should succeed
    Given the pod named "test-setuid" becomes ready
    And I execute on the pod:
      | id |
    Then the step should succeed
    And the output should match:
      | uid=\d+\s+gid=0\(root\)\s+groups=0\(root\),\d+ |
    And I execute on the pod:
      | bash | -c | echo redhat \| su - |
    Then the step should fail
    #The following error indicates the password is correct,
    #and the op is denied.
    #If an incorrect password is entered, the error message
    #will change to: Authentication failure, which is different
    #than what the bz is asking for.
    Then the output should contain:
      | su: cannot set groups: Operation not permitted |

