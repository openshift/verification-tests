Feature: taint toleration related scenarios

  # @author xiuli@redhat.com
  # @case_id OCP-13542
  @admin
  @destructive
  Scenario: OCP-13542 Add default tolerations to pod when enable DefaultTolerationSecond
    Given master config is merged with the following hash:
    """
    admissionConfig:
      pluginConfig:
        DefaultTolerationSeconds:
          configuration:
            kind: DefaultAdmissionConfig
            apiVersion: v1
            disable: false
    """
    And the master service is restarted on all master nodes
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/infrastructure/hpa/hello-pod.yaml |
    Then the step should succeed
    Given the pod named "hello-pod" becomes ready
    When I run the :describe client command with:
      | resource | pod       |
      | name     | hello-pod |
    Then the step should succeed
    And the output should match:
      | Tolerations:.*300s |
   
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/tolerations/defaultTolerationSeconds-override.yaml |
    Then the step should succeed
    Given the pod named "mytoleration" becomes ready
    When I run the :describe client command with:
      | resource | pod          |
      | name     | mytoleration |
    Then the step should succeed
    And the output should match:
      | Tolerations:.*60s |  
    
    Given admin ensures "hello-pod" pod is deleted from the project
    Given master config is merged with the following hash:
    """
    admissionConfig:
      pluginConfig:
        DefaultTolerationSeconds:
          configuration:
            kind: DefaultAdmissionConfig
            apiVersion: v1
            disable: true
    """
    And the master service is restarted on all master nodes
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/infrastructure/hpa/hello-pod.yaml |
    Then the step should succeed
    When I run the :describe client command with:
      | resource | pod       |
      | name     | hello-pod |
    Then the step should succeed
    And the output should not contain "NoExecute"

