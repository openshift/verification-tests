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
