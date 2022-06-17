Feature: scale related features

  # @author yanpzhan@redhat.com
  # @case_id OCP-11196
  Scenario: OCP-11196 Could scale up and down on overview page
    Given I have a project
    #Create pod with dc
    When I run the :run client command with:
      | name   | mytest                    |
      | image  | aosqe/hello-openshift     |
      | -l     | label=test                |
      | limits | memory=256Mi              |
    Then the step should succeed

    Given a pod becomes ready with labels:
      | label=test |

    When I perform the :goto_overview_page web console action with:
      | project_name | <%= project.name %> |
    Then the step should succeed

    #check replicas is 1
    When I perform the :check_pod_scaled_numbers web console action with:
      | resource_name | mytest     |
      | resource_type | deployment |
      | scaled_number | 1          |
    Then the step should succeed

    #scale up 3 times
    Given I run the steps 3 times:
    """
    When I run the :scale_up_once web console action
    Then the step should succeed
    """
    #check replicas is 4
    And I wait until number of replicas match "4" for replicationController "mytest-1"
    And I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 4 |
    Then the step should succeed

    #scale down 2 times
    Given I run the steps 2 times:
    """
    When I run the :scale_down_once web console action
    Then the step should succeed
    """
    #check replicas is 2
    And I wait until number of replicas match "2" for replicationController "mytest-1"
    Given I wait 180 seconds for the :check_pod_scaled_numbers web console action to succeed with:
      | scaled_number | 2 |

    #scale up 2 times
    Given I run the steps 2 times:
    """
    When I run the :scale_up_once web console action
    Then the step should succeed
    """
    And I wait until number of replicas match "4" for replicationController "mytest-1"
    #check replicas is 4
    And I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 4 |
    Then the step should succeed

    #scale down 2 times
    Given I run the steps 2 times:
    """
    When I run the :scale_down_once web console action
    Then the step should succeed
    Given 3 seconds have passed
    """

    And I wait until number of replicas match "2" for replicationController "mytest-1"
    #check replicas is 2
    Given I wait 180 seconds for the :check_pod_scaled_numbers web console action to succeed with:
      | scaled_number | 2 |

    #scale down to 0
    When I run the :scale_down_once web console action
    Then the step should succeed

    When I run the :cancel_scale_down_to_zero web console action
    Then the step should succeed
    And I perform the :check_pod_scaled_numbers web console action with:
      | scaled_number | 1 |
    When I run the :scale_down_to_zero web console action
    Then the step should succeed

    Given I wait 180 seconds for the :check_pod_scaled_numbers web console action to succeed with:
      | scaled_number | 0 |

    #check the scale down button is disabled
    When I run the :check_scale_down_disabled web console action
    Then the step should succeed

    When I run the :scale_up_once web console action
    Then the step should succeed

