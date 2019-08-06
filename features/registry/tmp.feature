Feature: Testing image registry operator

  # @author wzheng@redhat.com
  # @case_id OCP-21593
  @admin
  @destructive
  Scenario: test
    Given I switch to cluster admin pseudo user
    Given current generation number of image-registry deployment is stored into :before_generation clipboard
    When I run the :patch client command with:
      | resource      | configs.imageregistry.operator.openshift.io |
      | resource_name | cluster                                     |
      | p             | {"spec":{"logging":8}}    |
      | type          | merge                                       |
    Then the step should succeed 	
    Given current generation number of image-registry deployment is stored into :later_generation clipboard
    And the expression should be true> cb.later_generation - cb.before_generation >= 1
