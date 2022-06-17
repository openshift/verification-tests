Feature: Service-catalog related scenarios

  # @author chezhang@redhat.com
  # @case_id OCP-15600
  @admin
  @destructive
  Scenario: OCP-15600 service-catalog walkthrough example
    Given I have a project
    And evaluation of `project.name` is stored in the :ups_broker_project clipboard
    And I create a new project
    And evaluation of `project.name` is stored in the :user_project clipboard

    # Deploy ups broker
    Given I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type       | clusterservicebroker |
      | object_name_or_id | ups-broker           |
    the step should fail
    """
    When I switch to cluster admin pseudo user
    And I use the "<%= cb.ups_broker_project %>" project
    When I run the :new_app client command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/ups-broker-template.yaml |
      | param | UPS_BROKER_PROJECT=<%= cb.ups_broker_project %>                                                         |
    Then the step should succeed
    And I wait for the steps to pass:
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
    When I run the :new_app client command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/ups-instance-template.yaml |
      | param | USER_PROJECT=<%= cb.user_project %>                                                                       |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | serviceinstance/ups-instance |
    Then the output should match "Message.*The instance was provisioned successfully"
    """

    # Create servicebinding
    When I run the :new_app client command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/ups-binding-template.yaml |
      | param | USER_PROJECT=<%= cb.user_project %>                                                                      |
    Then the step should succeed
    Given I check that the "my-secret" secret exists
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
  # @case_id OCP-14833
  @admin
  Scenario: OCP-14833 Confirm service-catalog image working well
    When I switch to cluster admin pseudo user
    And I use the "kube-service-catalog" project
    Given 1 pods become ready with labels:
      | app=apiserver |
    When I execute on the pod:
      | sh |
      | -c |
      | /usr/bin/service-catalog --version; /usr/bin/service-catalog --help |
    Then the output by order should match:
      | v[0-9].[0-9].[0-9] |
      | apiserver          |
      | controller-manager |
    Given 1 pods become ready with labels:
      | app=controller-manager |
    When I execute on the pod:
      | sh |
      | -c |
      | /usr/bin/service-catalog --version; /usr/bin/service-catalog --help |
    Then the output by order should match:
      | v[0-9].[0-9].[0-9] |
      | apiserver          |
      | controller-manager |
    Given I use the "openshift-ansible-service-broker" project
    And 1 pods become ready with labels:
      | app=openshift-ansible-service-broker |
    When I execute on the pod:
      | sh |
      | -c |
      | /usr/bin/asbd --version; /usr/bin/asbd --help |
    Then the output by order should match:
      | [0-9].[0-9].[0-9]   |
      | Application Options |
      | Help Options        |

  # @author chezhang@redhat.com
  # @case_id OCP-15604
  @admin
  @destructive
  Scenario: OCP-15604 Create/get/update/delete for ClusterServiceBroker resource	
    Given I have a project
    And evaluation of `project.name` is stored in the :ups_broker_project clipboard

    # Deploy ups broker
    Given I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type       | clusterservicebroker |
      | object_name_or_id | ups-broker           |
    the step should fail
    """
    When I switch to cluster admin pseudo user
    And I use the "<%= cb.ups_broker_project %>" project
    When I run the :new_app client command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/ups-broker-template.yaml |
      | param | UPS_BROKER_PROJECT=<%= cb.ups_broker_project %>                                                         |
    Then the step should succeed
    And I wait for the steps to pass:
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
  # @case_id OCP-15602
  @admin
  @destructive
  Scenario: OCP-15602 Create/get/update/delete for Clusterserviceclass/Clusterserviceplan resource
    Given I have a project

    # Deploy ups broker
    Given admin ensures "ups-broker" clusterservicebroker is deleted after scenario

    When I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run the :new_app client command with:
      | file  | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/ups-broker-template.yaml |
      | param | UPS_BROKER_PROJECT=<%= project.name %>                                                                  |
    Then the step should succeed
    And I wait for the steps to pass:
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
    Given I ensures "<%= cb.class_id %>" clusterserviceclasses is deleted
    And I ensures "<%= cb.plan_id %>" clusterserviceplans is deleted
    And I ensures "ups-broker" clusterservicebroker is deleted
    When I run the :get client command with:
      | resource | clusterserviceclass                                        |
      | o        | custom-columns=BROKER\ NAME:.spec.clusterServiceBrokerName |
    Then the output should not contain "ups-broker"
    When I run the :get client command with:
      | resource | clusterserviceplan                                         |
      | o        | custom-columns=BROKER\ NAME:.spec.clusterServiceBrokerName |
    Then the output should not contain "ups-broker"

