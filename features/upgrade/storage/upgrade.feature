Feature: Storage upgrade tests
  # @author wduan@redhat.com
  # @case_id OCP-23501
  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  Scenario: Cluster operator storage should be in correct status and dynamic provisioning should work well after upgrade - prepare
    Given I switch to cluster admin pseudo user
    # Check cluster operator storage should be in correct status
    Given the expression should be true> cluster_operator('storage').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('storage').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('storage').condition(type: 'Degraded')['status'] == "False"
    Given the expression should be true> cluster_operator('storage').condition(type: 'Upgradeable')['status'] == "True"

    # There should be one and only one default storage class
    When I run the :get client command with:
      | resource      | clusteroperator                                                         |
      | resource_name | storage                                                                 |
      | o             | jsonpath={.status.relatedObjects[?(@.resource=="storageclasses")].name} |
    And evaluation of `@result[:response]` is stored in the :default_sc clipboard
    When I log the messages:
      | <%= cb.default_sc %> (default)  |
    When I run the :get client command with:
      | resource | storageclass |
    Then the step should succeed
    And the output should contain 1 times:
      | (default) |
    And the output should contain 1 times:
      | <%= cb.default_sc %> (default) |
    When I run the :get client command with:
      | resource | storageclass |
      | o        | yaml         |
    Then the step should succeed
    And the output should contain 1 times:
      | is-default-class: "true" |
    When I run the :get client command with:
      | resource      | storageclass         |
      | resource_name | <%= cb.default_sc %> |
      | o             | yaml                 |
    Then the step should succeed
    And the output should contain:
      | is-default-class: "true" |

    # Create deployment with default storage class
    When I run the :new_project client command with:
      | project_name | upgrade-ocp-23501 |
    When I use the "upgrade-ocp-23501" project
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc01-ocp-23501 |
    Then the step should succeed
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/misc/deployment.yaml" replacing paths:
      | ["metadata"]["name"]                                                             | mydep01-ocp-23501 |
      | ["spec"]["template"]["metadata"]["labels"]["action"]                             | upgrade-prepare   |
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc01-ocp-23501 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=upgrade-prepare |
    When I execute on the pod:
      | touch | /mnt/storage/test-before-upgrade |
    Then the step should succeed
    When I execute on the pod:
      | ls | /mnt/storage |
    Then the output should contain:
      | test-before-upgrade |

  # @author wduan@redhat.com
  @upgrade-check
  @users=upuser1,upuser2
  @admin
  Scenario: Cluster operator storage should be in correct status and dynamic provisioning should work well after upgrade
    Given I switch to cluster admin pseudo user
    # Check storage operator version after upgraded
    Given the "storage" operator version matches the current cluster version

    # Check cluster operator storage should be in correct status
    Given the expression should be true> cluster_operator('storage').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('storage').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('storage').condition(type: 'Degraded')['status'] == "False"
    Given the expression should be true> cluster_operator('storage').condition(type: 'Upgradeable')['status'] == "True"

    # There should be one and only one default storage class
    When I run the :get client command with:
      | resource      | clusteroperator                                                         |
      | resource_name | storage                                                                 |
      | o             | jsonpath={.status.relatedObjects[?(@.resource=="storageclasses")].name} |
    And evaluation of `@result[:response]` is stored in the :default_sc clipboard
    When I log the messages:
      | <%= cb.default_sc %> (default)  |
    When I run the :get client command with:
      | resource | storageclass |
    Then the step should succeed
    And the output should contain 1 times:
      | (default) |
    And the output should contain 1 times:
      | <%= cb.default_sc %> (default) |
    When I run the :get client command with:
      | resource | storageclass |
      | o        | yaml         |
    Then the step should succeed
    And the output should contain 1 times:
      | is-default-class: "true" |
    When I run the :get client command with:
      | resource      | storageclass         |
      | resource_name | <%= cb.default_sc %> |
      | o             | yaml                 |
    Then the step should succeed
    And the output should contain:
      | is-default-class: "true" |

    # Check deployment and data before upgrade
    When I use the "upgrade-ocp-23501" project
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=upgrade-prepare |
    When I execute on the pod:
      | touch | /mnt/storage/test-after-upgrade |
    Then the step should succeed
    When I execute on the pod:
      | ls | /mnt/storage |
    Then the output should contain:
      | test-before-upgrade |
      | test-after-upgrade  |

    # Create deployment with default storage class
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc02-ocp-23501 |
    Then the step should succeed
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/misc/deployment.yaml" replacing paths:
      | ["metadata"]["name"]                                                             | mydep02-ocp-23501 |
      | ["spec"]["template"]["metadata"]["labels"]["action"]                             | upgrade-check     |
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc02-ocp-23501 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | action=upgrade-check |
    When I execute on the pod:
      | touch | /mnt/storage/test-upgrade |
    Then the step should succeed
    When I execute on the pod:
      | ls | /mnt/storage |
    Then the output should contain:
      | test-upgrade |
