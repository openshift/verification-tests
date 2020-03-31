@asb
Feature: ASB related scenarios
    
  # @author chuo@redhat.com
  # @case_id OCP-28919
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  Scenario: upgrade ASB - prepare
    # Create a namespace and an operator in it
    Given I switch to cluster admin pseudo user
    When I run the :oadm_new_project client command with:
      | project_name | openshift-ansible-service-broker |
    Then the step should succeed

    # Install the art or aopqe4 OperatorSource. 
    # TODO: it's better to set the below steps in CI post action.
    # When I process and create:
    #   | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/olm/art-secret-ansible.yaml |
    #   | p | NAME=aosqe4-secret                                                                              |
    #   | p | TOKEN=<your quay token>                                                                         |
    # Then the step should succeed
    # When I process and create:
    #   | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/olm/operatorsource-ansible.yaml |
    #   | p | NAME=aosqe4-operators                                                                               |
    #   | p | SECRET=aosqe4-secret                                                                                |
    #   | p | REGISTRY=aosqe4                                                                                     |
    # Then the step should succeed
    # Enable Service Catalog so that the ASB can work well
    Given enable service catalog
    # Get the cluster version: oc get clusterversion version -o=jsonpath='{.spec.channel}' | tr -d 'stable-'
    Given the major.minor version of the cluster is stored in the clipboard

    # This step will install the OperatorGroup, operator. Please use your operator Package name in here.
    Given optional operator "openshiftansibleservicebroker" from channel "<%= cb.operator_channel_name %>" is subscribed in "openshift-ansible-service-broker" project
    # Check the pods of the operator
    Then I wait for the "openshift-ansible-service-broker-operator" deployment to appear
    And I wait up to 180 seconds for the steps to pass:
    """
    And a pod becomes ready with labels:
        | name=openshift-ansible-service-broker-operator-alm-owned |
    """
    # Check if the corresponding CRD is ready
    Then I run the :get client command with:
      | resource | automationbroker |
    And the output should contain "No resources found"
    #Create Cluster Role Binding for the operator
    When I process and create:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/olm/asb-rolebinding-template.yaml |
    Then the step should succeed
    # Create customer resource for the operator
    When I process and create:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/olm/asb-cr-template.yaml |
    Then the step should succeed
    And I wait up to 180 seconds for the steps to pass:
    """
    And a pod becomes ready with labels:
        | app=ansible-service-broker |
    """
    
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  Scenario: upgrade ASB
    Given I switch to cluster admin pseudo user
    And I use the "openshift-ansible-service-broker" project
    # Check if the previous ASB works works well.
    When I run the :describe client command with:
      | resource           | clusterservicebroker    |
      | name               | ansible-service-broker |
    And the output should match:
      | Reason:\\s+FetchedCatalog |
      | Status:\\s+True           |

    # Update ASB operator to the new version
    Given the major.minor version of the cluster is stored in the clipboard
    When I run the :patch client command with:
      | resource      | subscription                                              |
      | resource_name | openshiftansibleservicebroker-sub                        |
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
        | name=openshift-ansible-service-broker-operator-alm-owned |
    """
    # Check if the ASB operator works well, if yes, the ASB can be removed successfully
    When I run the :delete client command with:
      | object_type        | automationbroker                 |
      | object_name_or_id  | ansible-service-broker           |
      | n                  | openshift-ansible-service-broker |
    Then the step should succeed
    And I wait up to 240 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | clusterservicebroker |
    And the output should contain "No resources found"
    """
    # Recreate a ASB
    When I process and create:
      | f | <%= ENV['BUSHSLICER_HOME'] %>/testdata/olm/asb-cr-template.yaml |
    Then the step should succeed
    And I wait up to 180 seconds for the steps to pass:
    """
    And a pod becomes ready with labels:
      | app=ansible-service-broker |
    """
    # Check if the new ASB works works well.
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource           | clusterservicebroker    |
      | name               | ansible-service-broker |
    And the output should match:
      | Reason:\\s+FetchedCatalog |
      | Status:\\s+True           |
    """
