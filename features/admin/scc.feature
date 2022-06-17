Feature: SCC policy related scenarios

  # @author pruan@redhat.com
  # @case_id OCP-11762
  @admin
  Scenario: OCP-11762 deployment hook volume inheritance with hostPath volume
    Given I have a project
    # Create hostdir pod again with new SCC
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/tc510609/scc_hostdir.yaml |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/tc510609/tc_dc.json |
    And I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type       | scc         |
      | object_name_or_id | scc-hostdir |
    the step should succeed
    """
    And the pod named "hooks-1-deploy" status becomes :running
    And the pod named "hooks-1-hook-pre" status becomes :running
    # step 2, check the pre-hook pod
    When I get project pod named "hooks-1-hook-pre" as YAML
    Then the step should succeed
    And the expression should be true> @result[:parsed]['spec']['volumes'].any? {|p| p['name'] == "data"} && @result[:parsed]['spec']['volumes'].any? {|p| p['hostPath']['path'] == "/usr"}

  # @author yinzhou@redhat.com
  # @case_id OCP-11775
  @admin
  Scenario: OCP-11775 Create or update scc with illegal capability name should fail with prompt message
    Given I have a project
    Given admin ensures "scc-cap" scc is deleted after scenario
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_capabilities.yaml"
    And I replace lines in "scc_capabilities.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
      |scc-cap|<%= rand_str(6, :dns) %>|
      |KILL|KILLtest|
    And the following scc policy is created: scc_capabilities.yaml
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/pod_requests_cap_chown.json"
    And I replace lines in "pod_requests_cap_chown.json":
      |CHOWN|KILLtest|
    When I run the :create client command with:
      |f|pod_requests_cap_chown.json|
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When  I run the :describe client command with:
      | resource | pod           |
      | name     | pod-add-chown |
    Then the output should match:
      | [uU]nknown\|invalid capability[ .*to add]? |
      | (?i)CAP_KILLtest                           |
    """
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc_with_confilict_capabilities.yaml"
    And I replace lines in "scc_with_confilict_capabilities.yaml":
      |system:serviceaccounts:default|system:serviceaccounts:<%= project.name %>|
    When I run the :create admin command with:
       | f | scc_with_confilict_capabilities.yaml |
    Then the step should fail
    And the output should contain "capability is listed in defaultAddCapabilities and requiredDropCapabilities"
    And I replace lines in "scc_with_confilict_capabilities.yaml":
      |defaultAddCapabilities:||
    When I run the :create admin command with:
      | f | scc_with_confilict_capabilities.yaml |
    Then the step should fail
    And the output should contain "capability is listed in allowedCapabilities and requiredDropCapabilities"

