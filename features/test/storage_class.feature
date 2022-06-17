Feature: StorageClass testing scenarios

  @admin
  Scenario: admin creates a StorageClass
    Given I have a project
    When admin creates a StorageClass from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/misc/storageClass.yaml" where:
      | ["metadata"]["name"] | sc-<%= project.name %> |
      | ["provisioner"]      | kubernetes.io/manual   |
    Then the step should succeed
    When I run the :get admin command with:
      | resource      | storageclass           |
      | resource_name | sc-<%= project.name %> |
      | o             | yaml                   |
    Then the step should succeed

  @admin
  Scenario: Add option allowVolumeExpansion to StorageClass
    Given I check feature gate "ExpandPersistentVolumes" with admission "PersistentVolumeClaimResize" is enabled
    When I run the :get admin command with:
      | resource | storageclass |
      | o        | yaml         |
    Then the step should succeed
    And as admin I successfully patch resource "storageclass/standard" with:
      | {"allowVolumeExpansion":true,"metadata":{"annotations":{"updatedBy":"<%=project.name%>-<%=Time.new%>"}}} |
    When I run the :get admin command with:
      | resource | storageclass |
      | o        | yaml         |
    Then the step should succeed
    # Multi times
    Given as admin I successfully patch resource "storageclass/standard" with:
      | {"allowVolumeExpansion":true,"metadata":{"annotations":{"updatedBy":"<%=project.name%>-<%=Time.new%>"}}} |

  @admin
  @destructive
  Scenario: Clone storage class
    Given admin clones storage class "test1" from ":default" with:
      | ["parameters"]["resturl"] | "http://error.address.com" |
    And admin clones storage class "test2" from ":default" with volume expansion enabled
    And admin clones storage class "my-default" from ":default" with:
      | ["metadata"]["annotations"]["storageclass.beta.kubernetes.io/is-default-class"] | "true" |
    When I run the :get admin command with:
      | resource      | storageclass |
      | resource_name | test1        |
      | resource_name | test2        |
      | resource_name | my-default   |
      | o             | yaml         |
    Then the step should succeed
