@svcat
Feature: Service Catalog related scenarios
    
  # @author jfan@redhat.com
  # @case_id OCP-22621
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: upgrade svcat - prepare
    # Check SVCAT version
    Given the "service-catalog-apiserver" operator version matchs the current cluster version
    # Check cluster operator svcat-apiserver status
    Given the status of condition "Degraded" for "service-catalog-apiserver" operator is: False
    Given the status of condition "Progressing" for "service-catalog-apiserver" operator is: False
    Given the status of condition "Available" for "service-catalog-apiserver" operator is: True
    Given the status of condition "Upgradeable" for "service-catalog-apiserver" operator is: Unknown
    # Check cluster operator svcat-controller status
    Given the "service-catalog-controller-manager" operator version matchs the current cluster version
    Given the status of condition "Degraded" for "service-catalog-controller-manager" operator is: False
    Given the status of condition "Progressing" for "service-catalog-controller-manager" operator is: False
    Given the status of condition "Available" for "service-catalog-controller-manager" operator is: True
    Given the status of condition "Upgradeable" for "service-catalog-controller-manager" operator is: True
    #enable the svcat
    Given I switch to cluster admin pseudo user
    When I run the :patch client command with:
      | resource      | ServiceCatalogAPIServer                 |
      | resource_name | cluster                                 |
      | p             | {"spec":{"managementState": "Managed"}} |
      | type          | merge                                   |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      | ServiceCatalogControllerManager         |
      | resource_name | cluster                                 |
      | p             | {"spec":{"managementState": "Managed"}} |
      | type          | merge                                   |
    Then the step should succeed
    
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  Scenario: upgrade svcat
    # Check cluster operator svcat-apiserver status
    Given the "service-catalog-apiserver" operator version matchs the current cluster version
    Given the status of condition "Degraded" for "service-catalog-apiserver" operator is: False
    Given the status of condition "Progressing" for "service-catalog-apiserver" operator is: False
    Given the status of condition "Available" for "service-catalog-apiserver" operator is: True
    Given the status of condition "Upgradeable" for "service-catalog-apiserver" operator is: True
    # Check cluster operator svcat-controller status
    Given the "service-catalog-controller-manager" operator version matchs the current cluster version
    Given the status of condition "Degraded" for "service-catalog-controller-manager" operator is: False
    Given the status of condition "Progressing" for "service-catalog-controller-manager" operator is: False
    Given the status of condition "Available" for "service-catalog-controller-manager" operator is: True
    Given the status of condition "Upgradeable" for "service-catalog-controller-manager" operator is: True
    
    # Deploy ups broker
    When I run the :get admin command with:
      | resource | clusterservicebroker |
    Then the step should succeed  
    Given I have a project
    When I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I process and create:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/ups-broker-template.yaml |
      | p | UPS_BROKER_PROJECT=<%= project.name %>                                                                  |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | clusterservicebroker/ups-broker |
    Then the output should contain "Successfully fetched catalog entries from broker"
    """
    When I run the :get client command with:
      | resource | clusterserviceclass                                                       |
      | o        | custom-columns=CLASSNAME:.metadata.name,EXTERNAL\ NAME:.spec.externalName |
    Then the output should contain "user-provided"

    #Provision a serviceinstance
    Given I switch to the first user
    And I use the "<%= cb.user_project %>" project
    When I process and create:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/svc-catalog/ups-instance-template.yaml |
      | p | USER_PROJECT=<%= cb.user_project %>                                                                       |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | serviceinstance/ups-instance |
    Then the output should match "Message.*The instance was provisioned successfully"
    """

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
