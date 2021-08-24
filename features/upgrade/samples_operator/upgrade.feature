Feature: image-registry operator upgrade tests
  # @author xiuwang@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  Scenario: samples/openshift-controller-manager/image-registry operators should be in correct status after upgrade - prepare
    Given I switch to cluster admin pseudo user
    # Check cluster operator openshift-samples should be in correct status
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Degraded')['status'] == "False"
    # Check cluster operator image-registry should be in correct status
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Degraded')['status'] == "False"
    # Check cluster operator openshift-controller-manager should be in correct status
    Given the expression should be true> cluster_operator('openshift-controller-manager').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-controller-manager').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('openshift-controller-manager').condition(type: 'Degraded')['status'] == "False"

  # @author wzheng@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  @destructive
  Scenario: OpenShift can upgrade when image-registry/sample operator is unmanaged - prepare
    Given I switch to cluster admin pseudo user
    Given admin updated the operator crd "configs.imageregistry" managementstate operand to Unmanaged
    Given admin updated the operator crd "config.samples" managementstate operand to Unmanaged
    # Check cluster operator openshift-samples should be in correct status
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Degraded')['status'] == "False"
    # Check cluster operator image-registry should be in correct status
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Degraded')['status'] == "False"

  # @author xiuwang@redhat.com
  # @case_id OCP-22678
  @upgrade-check
  @users=upuser1,upuser2
  @admin
  Scenario: samples/openshift-controller-manager/image-registry operators should be in correct status after upgrade
    Given I switch to cluster admin pseudo user
    # Check cluster operator openshift-samples should be in correct status
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Degraded')['status'] == "False"
    # Check cluster operator image-registry should be in correct status
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Degraded')['status'] == "False"
    # Check cluster operator openshift-controller-manager should be in correct status
    Given the expression should be true> cluster_operator('openshift-controller-manager').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-controller-manager').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('openshift-controller-manager').condition(type: 'Degraded')['status'] == "False"

  # @author wzheng@redhat.com
  # @case_id OCP-27983
  @upgrade-check
  @users=upuser1,upuser2
  @admin
  @inactive
  Scenario: OpenShift can upgrade when image-registry/sample operator is unmanaged
    Given I switch to cluster admin pseudo user
    Given I use the "default" project
    When I get project config_imageregistry_operator_openshift_io named "cluster" as YAML
    Then the output should contain:
      | Unmanaged |
    When I get project config_samples_operator_openshift_io named "cluster" as YAML
    Then the output should contain:
      | Unmanaged |
    # Check cluster operator openshift-samples should be in correct status
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('openshift-samples').condition(type: 'Degraded')['status'] == "False"
    # Check cluster operator image-registry should be in correct status
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('image-registry').condition(type: 'Degraded')['status'] == "False"

  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  Scenario: Upgrade imagestream from old version which not implement node credentials - prepare
    Given I switch to cluster admin pseudo user
    When I run the :extract admin command with:
      | resource  | secret/pull-secret |
      | namespace | openshift-config   |
      | to        | /tmp               |
      | confirm   | true               |
    Then the step should succeed
    When I run the :new_project client command with:
      | project_name | devexp-p1 |
    Then the step should succeed
    When I use the "devexp-p1" project
    When I run the :create_secret client command with:
      | secret_type | generic                                  |
      | name        | pj-secret                                |
      | from_file   | .dockerconfigjson=/tmp/.dockerconfigjson |
      | type        | kubernetes.io/dockerconfigjson           |
    Then the step should succeed
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream1:latest                           |
      | reference-policy | local                                         |
    Then the step should succeed
    And the output should not contain:
      | error: Import failed |
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream2:latest                           |
    Then the step should succeed
    And the output should not contain:
      | error: Import failed |
    When I run the :new_project client command with:
      | project_name | devexp-p2 |
    Then the step should succeed
    When I use the "devexp-p2" project
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream3:latest                           |
      | reference-policy | local                                         |
    Then the step should succeed
    And the output should contain:
      | error: Import failed |
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream4:latest                           |
    Then the step should succeed
    And the output should contain:
      | error: Import failed |

  # @author xiuwang@redhat.com
  # @case_id OCP-29709
  @upgrade-check
  @users=upuser1,upuser2
  @admin
  @inactive
  Scenario: Upgrade imagestream from old version which not implement node credentials
    Given I switch to cluster admin pseudo user
    When I use the "devexp-p1" project
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream1:latest                           |
      | reference-policy | local                                         |
    Then the step should succeed
    And the output should not contain:
      | error: Import failed |
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream2:latest                           |
    Then the step should succeed
    And the output should not contain:
      | error: Import failed |
    When I use the "devexp-p2" project
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream3:latest                           |
      | reference-policy | local                                         |
    Then the step should succeed
    And the output should not contain:
      | error: Import failed |
    When I run the :import_image client command with:
      | from             | registry.redhat.io/rhscl/ruby-25-rhel7:latest |
      | confirm          | true                                          |
      | image_name       | imagestream4:latest                           |
    Then the step should succeed
    And the output should not contain:
      | error: Import failed |
