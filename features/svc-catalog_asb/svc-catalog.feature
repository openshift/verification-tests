Feature: Service-catalog related scenarios

  # @author chezhang@redhat.com
  # @case_id OCP-15600
  @admin
  @destructive
  @inactive
  Scenario: service-catalog walkthrough example
    Given I have a project
    When I run the :get admin command with:
      | resource | clusterservicebroker |
    Then the step should succeed
    And evaluation of `project.name` is stored in the :ups_broker_project clipboard
    And I create a new project
    And evaluation of `project.name` is stored in the :user_project clipboard

    # Deploy ups broker

    Given admin ensures "ups-broker" clusterservicebroker is deleted after scenario
    When I switch to cluster admin pseudo user
    And I use the "<%= cb.ups_broker_project %>" project
    Given I obtain test data file "svc-catalog/ups-broker-template.yaml"
    When I process and create:
      | f | ups-broker-template.yaml |
      | p | UPS_BROKER_PROJECT=<%= cb.ups_broker_project %>                                                         |
    Then the step should succeed
    And I wait up to 360 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should contain "Successfully fetched catalog entries from broker"
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=CLASSNAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should contain "user-provided"
    """

    #Provision a serviceinstance
    Given I switch to the first user
    And I use the "<%= cb.user_project %>" project
    Given I obtain test data file "svc-catalog/ups-instance-template.yaml"
    When I process and create:
      | f | ups-instance-template.yaml |
      | p | USER_PROJECT=<%= cb.user_project %>                                                                       |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | serviceinstance/ups-instance |
    Then the output should match "Message.*The instance was provisioned successfully"
    """

    # Create servicebinding
    Given I obtain test data file "svc-catalog/ups-binding-template.yaml"
    When I process and create:
      | f | ups-binding-template.yaml |
      | p | USER_PROJECT=<%= cb.user_project %>                                                                      |
    Then the step should succeed
    Given I wait for the "my-secret" secret to appear up to 60 seconds

    And I wait up to 10 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | servicebinding |
    Then the output should match "Message.*Injected bind result"
    """

    # Delete servicebinding
    When I run the :delete client command with:
      | object_type       | servicebinding |
      | object_name_or_id | ups-binding    |
    Then the step should succeed
    Given I wait for the resource "servicebinding" named "ups-binding" to disappear within 60 seconds
    And I wait for the resource "secret" named "my-secret" to disappear within 60 seconds

    # Delete serviceinstance
    When I run the :delete client command with:
      | object_type       | serviceinstance |
      | object_name_or_id | ups-instance    |
    Then the step should succeed
    Given I wait for the resource "serviceinstance" named "ups-instance" to disappear within 60 seconds

    # Delete ups broker
    When I switch to cluster admin pseudo user
    When I run the :delete client command with:
      | object_type       | clusterservicebroker |
      | object_name_or_id | ups-broker           |
    Then the step should succeed
    And I wait for the resource "clusterservicebrokers" named "ups-broker" to disappear within 60 seconds
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=CLASSNAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should not contain "user-provided"

  # @author chezhang@redhat.com
  # @case_id OCP-15604
  @admin
  @destructive
  @inactive
  Scenario: Create/get/update/delete for ClusterServiceBroker resource
    Given I have a project
    When I run the :get admin command with:
      | resource | clusterservicebroker |
    Then the step should succeed
    And evaluation of `project.name` is stored in the :ups_broker_project clipboard

    # Deploy ups broker
    Given admin ensures "ups-broker" clusterservicebroker is deleted after scenario
    When I switch to cluster admin pseudo user
    And I use the "<%= cb.ups_broker_project %>" project
    Given I obtain test data file "svc-catalog/ups-broker-template.yaml"
    When I process and create:
      | f | ups-broker-template.yaml |
      | p | UPS_BROKER_PROJECT=<%= cb.ups_broker_project %>                                                         |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should contain "Successfully fetched catalog entries from broker"
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=CLASSNAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should contain "user-provided"
    """

    #Check yaml output of clusterservicebroker
    When I run the :get client command with:
      | resource | clusterservicebroker/ups-broker |
      | o        | yaml                            |
    Then the output should match:
      | kind:\\s+ClusterServiceBroker                                            |
      | generation                                                               |
      | name:\\s+ups-broker                                                      |
      | relistBehavior                                                           |
      | relistRequests                                                           |
      | url:\\s+http://ups-broker.<%= cb.ups_broker_project %>.svc.cluster.local |
      | reconciledGeneration                                                     |

    #Update clusterservicebroker
    When I run the :patch client command with:
      | resource | clusterservicebroker/ups-broker                                                          |
      | p        | {"spec":{"url": "http://testups-broker.<%= cb.ups_broker_project %>.svc.cluster.local"}} |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should match "Error getting broker catalog.*testups-broker"
    """
    When I run the :patch client command with:
      | resource | clusterservicebroker/ups-broker                                                      |
      | p        | {"spec":{"url": "http://ups-broker.<%= cb.ups_broker_project %>.svc.cluster.local"}} |
    Then the step should succeed
    And I wait up to 20 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should match "Message.*Successfully fetched catalog entries from broker"
    """

    # Delete ups broker
    When I switch to cluster admin pseudo user
    When I run the :delete admin command with:
      | object_type       | clusterservicebroker |
      | object_name_or_id | ups-broker           |
    Then the step should succeed
    And I wait for the resource "clusterservicebrokers" named "ups-broker" to disappear within 60 seconds
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=CLASSNAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should not contain "user-provided"

  # @author chezhang@redhat.com
  # @case_id OCP-15603
  @admin
  @destructive
  @inactive
  Scenario: Create/get/update/delete for ServiceInstance resource
    Given I have a project
    When I run the :get admin command with:
      | resource | clusterservicebroker |
    Then the step should succeed
    And evaluation of `project.name` is stored in the :ups_broker_project clipboard
    And I create a new project
    And evaluation of `project.name` is stored in the :user_project clipboard

    # Deploy ups broker
    Given admin ensures "ups-broker" clusterservicebroker is deleted after scenario
    Given admin ensures "ups-instance" serviceinstance is deleted
    When I switch to cluster admin pseudo user
    And I use the "<%= cb.ups_broker_project %>" project
    Given I obtain test data file "svc-catalog/ups-broker-template.yaml"
    When I process and create:
      | f | ups-broker-template.yaml |
      | p | UPS_BROKER_PROJECT=<%= cb.ups_broker_project %>                                                         |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should contain "Successfully fetched catalog entries from broker"
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=CLASSNAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should contain "user-provided"
    """

    #Provision a serviceinstance
    Given I switch to the first user
    And I use the "<%= cb.user_project %>" project
    Given I obtain test data file "svc-catalog/ups-instance-template.yaml"
    When I process and create:
      | f | ups-instance-template.yaml |
      | p | USER_PROJECT=<%= cb.user_project %>                                                                       |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | serviceinstance/ups-instance |
    Then the output should match "Message.*The instance was provisioned successfully"
    """

    #Update serviceinstance
    When I run the :patch client command with:
      | resource | serviceinstance/ups-instance                    |
      | p        | {"metadata":{"labels":{"app":"test-instance"}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource   | serviceinstance/ups-instance |
      | show_label | true                         |
    Then the output should contain "app=test-instance"
    Given admin ensures "ups-instance" serviceinstance is deleted

  # @author chezhang@redhat.com
  # @case_id OCP-15605
  @admin
  @destructive
  @inactive
  Scenario: Create/get/update/delete for ServiceBinding resource
    Given I have a project
    When I run the :get admin command with:
      | resource | clusterservicebroker |
    Then the step should succeed
    And evaluation of `project.name` is stored in the :ups_broker_project clipboard
    And I create a new project
    And evaluation of `project.name` is stored in the :user_project clipboard

    # Deploy ups broker
    Given admin ensures "ups-broker" clusterservicebroker is deleted after scenario
    When I switch to cluster admin pseudo user
    And I use the "<%= cb.ups_broker_project %>" project
    Given I obtain test data file "svc-catalog/ups-broker-template.yaml"
    When I process and create:
      | f | ups-broker-template.yaml |
      | p | UPS_BROKER_PROJECT=<%= cb.ups_broker_project %>                                                         |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should contain "Successfully fetched catalog entries from broker"
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=CLASSNAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should contain "user-provided"
    """

    #Provision a serviceinstance
    Given I switch to the first user
    And I use the "<%= cb.user_project %>" project
    Given I obtain test data file "svc-catalog/ups-instance-template.yaml"
    When I process and create:
      | f | ups-instance-template.yaml |
      | p | USER_PROJECT=<%= cb.user_project %>                                                                       |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | serviceinstance/ups-instance |
    Then the output should match "Message.*The instance was provisioned successfully"
    """

    # Create servicebinding
    Given I obtain test data file "svc-catalog/ups-binding-template.yaml"
    When I process and create:
      | f | ups-binding-template.yaml |
      | p | USER_PROJECT=<%= cb.user_project %>                                                                      |
    Then the step should succeed
    And I wait up to 10 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | servicebinding |
    Then the output should match "Message.*Injected bind result"
    """

    #Update servicebinding
    When I run the :patch client command with:
      | resource | servicebinding/ups-binding                     |
      | p        | {"metadata":{"labels":{"app":"test-binding"}}} |
    Then the step should succeed
    When I run the :get client command with:
      | resource   | servicebinding/ups-binding |
      | show_label | true                       |
    Then the output should contain "app=test-binding"

    # Delete servicebinding
    Given admin ensures "ups-binding" servicebinding is deleted
    And I wait for the resource "secret" named "my-secret" to disappear within 60 seconds

  # @author chezhang@redhat.com
  # @case_id OCP-15602
  @admin
  @destructive
  @inactive
  Scenario: Create/get/update/delete for Clusterserviceclass/Clusterserviceplan resource
    Given I have a project
    When I run the :get admin command with:
      | resource | clusterservicebroker |
    Then the step should succeed

    # Deploy ups broker
    Given admin ensures "ups-broker" clusterservicebroker is deleted after scenario

    When I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "svc-catalog/ups-broker-template.yaml"
    When I process and create:
      | f | ups-broker-template.yaml |
      | p | UPS_BROKER_PROJECT=<%= project.name %>                                                                  |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should contain "Successfully fetched catalog entries from broker"
    """
    Given cluster service classes are indexed by external name in the :csc clipboard
    And evaluation of `cb.csc['user-provided-service'].name` is stored in the :class_id clipboard

    # Check clusterserviceclass yaml
    When I run the :get client command with:
      | resource | clusterserviceclass/<%= cb.class_id %> |
      | o        | yaml                                   |
    Then the output should match:
      | bindable                                |
      | clusterServiceBrokerName:\\s+ups-broker |
      | description                             |
      | externalID                              |
      | externalName                            |
      | planUpdatable                           |

    # Check clusterserviceplan yaml
    When I run the :get client command with:
      | resource | clusterserviceplan                                                                                                 |
      | o        | custom-columns=NAME:.metadata.name,CLASS\ NAME:.spec.clusterServiceClassRef.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should contain "<%= cb.class_id %>"
    And evaluation of `cluster_service_class(cb.class_id).plans.first.name` is stored in the :plan_id clipboard
    When I run the :get client command with:
      | resource | clusterserviceplan/<%= cb.plan_id %> |
      | o        | yaml                                 |
    Then the output should match:
      | clusterServiceBrokerName:\\s+ups-broker |
      | clusterServiceClassRef                  |
      | description                             |
      | externalID                              |
      | externalName                            |
      | free                                    |

    # Update clusterserviceclasses and clusterserviceplans
    Given I successfully patch resource "clusterserviceclass/<%= cb.class_id %>" with:
      | {"metadata":{"labels":{"app":"test-class"}}} |
    And I successfully patch resource "clusterserviceplan/<%= cb.plan_id %>" with:
      | {"metadata":{"labels":{"app":"test-plan"}}} |

    # Delete the clusterserviceclass/clusterserviceplan/clusterservicebroker
    Given I ensure "<%= cb.class_id %>" clusterserviceclasses is deleted
    And I ensure "<%= cb.plan_id %>" clusterserviceplans is deleted
    And I ensure "ups-broker" clusterservicebroker is deleted
    When I run the :get client command with:
      | resource | clusterserviceclass                                        |
      | o        | custom-columns=BROKER\ NAME:.spec.clusterServiceBrokerName |
    Then the output should not contain "ups-broker"
    When I run the :get client command with:
      | resource | clusterserviceplan                                         |
      | o        | custom-columns=BROKER\ NAME:.spec.clusterServiceBrokerName |
    Then the output should not contain "ups-broker"

