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
  Scenario: OpenShift can upgrade when image-registry/sample operator is unmanaged - preapare
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
