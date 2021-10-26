Feature: kata and pod related scenarios
  # @author pruan@redhat.com
  # @case_id OCP-38468
  @4.10 @4.9
  @gcp-ipi
  @gcp-upi
  Scenario: Pod using kata runtime can have an initcontainer
    Given I have a project
    And I obtain test data file "kata/OCP-38468/pod_with_init_container.yaml"
    And I run the :create client command with:
      | f | pod_with_init_container.yaml |
    And I obtain test data file "kata/OCP-38468/services.yaml"
    And I run the :create client command with:
      | f | services.yaml |
    And the pod named "myapp-pod" becomes ready
    And evaluation of `pod.containers.first.status(type: 'init')` is stored in the :stat clipboard
    Then the expression should be true> cb[:stat].dig('state', 'terminated', 'reason') == 'Completed'
