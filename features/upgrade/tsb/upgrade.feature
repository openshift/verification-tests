@tsb
Feature: TSB related scenarios

  # @author jiazha@redhat.com
  # @case_id OCP-20584
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  @inactive
  Scenario: upgrade TSB - prepare
    # Create a namespace and an operator in it
    Given I switch to cluster admin pseudo user
    And I use the "openshift-template-service-broker" project
    # Create a project
    When I run the :oadm_new_project client command with:
      | project_name | openshift-template-service-broker |
    Then the step should succeed

    # Install the art or aopqe4 OperatorSource.
    # TODO: it's better to set the below steps in CI post action.
    # Given I obtain test data file "olm/art-secret-template.yaml"
    # When I process and create:
    #   | f | art-secret-template.yaml |
    #   | p | NAME=aosqe4-secret                                                                              |
    #   | p | TOKEN=<your quay token>                                                                         |
    # Then the step should succeed
    # Given I obtain test data file "olm/operatorsource-template.yaml"
    # When I process and create:
    #   | f | operatorsource-template.yaml |
    #   | p | NAME=aosqe4-operators                                                                               |
    #   | p | SECRET=aosqe4-secret                                                                                |
    #   | p | REGISTRY=aosqe4                                                                                     |
    # Then the step should succeed
    # Enable Service Catalog so that the ASB can work well
    Given enable service catalog
    # Get the cluster version: oc get clusterversion version -o=jsonpath='{.spec.channel}' | tr -d 'stable-'
    Given the major.minor version of the cluster is stored in the clipboard

    # This step will install the OperatorGroup, operator. Please use your operator Package name in here.
    Given optional operator "openshifttemplateservicebroker" from channel "<%= cb.operator_channel_name %>" is subscribed in "openshift-template-service-broker" project
    # Check the pods of the operator
    Then I wait for the "openshift-template-service-broker-operator" deployment to appear
    And I wait up to 180 seconds for the steps to pass:
    """
    And a pod becomes ready with labels:
        | name=openshift-template-service-broker-operator |
    """
    # Check if the corresponding CRD is ready
    Then I run the :get client command with:
      | resource | templateservicebroker |
    And the output should contain "No resources found"
    # Create customer resource for the operator
    Given I obtain test data file "olm/tsb-cr-template.yaml"
    When I process and create:
      | f | tsb-cr-template.yaml |
    Then the step should succeed
    And I wait up to 180 seconds for the steps to pass:
    """
    And a pod becomes ready with labels:
        | app=template-service-broker |
    """

  @admin
  @upgrade-check
  @inactive
  @users=upuser1,upuser2
  Scenario: upgrade TSB
    Given I switch to cluster admin pseudo user
    And I use the "openshift-template-service-broker" project
    # Check if the previous TSB works works well.
    When I run the :describe client command with:
      | resource           | clusterservicebroker    |
      | name               | template-service-broker |
    And the output should match:
      | Reason:\\s+FetchedCatalog |
      | Status:\\s+True           |

    # Update TSB operator to the new version
    Given the major.minor version of the cluster is stored in the clipboard
    When I run the :patch client command with:
      | resource      | subscription                                              |
      | resource_name | openshifttemplateservicebroker-sub                        |
      | p             | {"spec": {"channel": "<%= cb.operator_channel_name %>" }} |
      | type          | merge                                                     |
    Then the step should succeed

    And I wait up to 360 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | clusterserviceversion |
    Then the output should contain:
      | <%= cb.operator_channel_name %>  |
      | Succeeded                        |
    """
    And I wait up to 180 seconds for the steps to pass:
    """
    And a pod becomes ready with labels:
        | name=openshift-template-service-broker-operator |
    """
    # Check if the TSB operator works well, if yes, the TSB can be removed successfully
    When I run the :delete client command with:
      | object_type        | templateservicebroker             |
      | object_name_or_id  | template-service-broker           |
      | n                  | openshift-template-service-broker |
    Then the step should succeed
    And I wait up to 240 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | clusterservicebroker |
    And the output should contain "No resources found"
    """
    # Recreate a TSB
    Given I obtain test data file "olm/tsb-cr-template.yaml"
    When I process and create:
      | f | tsb-cr-template.yaml |
    Then the step should succeed
    And I wait up to 180 seconds for the steps to pass:
    """
    And a pod becomes ready with labels:
      | app=template-service-broker |
    """
    # Check if the new TSB works works well.
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource           | clusterservicebroker    |
      | name               | template-service-broker |
    And the output should match:
      | Reason:\\s+FetchedCatalog |
      | Status:\\s+True           |
    """
