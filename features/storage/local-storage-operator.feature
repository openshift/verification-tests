Feature: local-storage-operator related features

  # @author lxia@redhat.com
  # @case_id OCP-24493
  @admin
  @inactive
  Scenario: OCP-24493:Storage Operator local-storage exist in OperatorHub
    Given I switch to cluster admin pseudo user
    And admin uses the "openshift-marketplace" project
    And the expression should be true> opsrc("redhat-operators").packages&.include? "local-storage-operator"
