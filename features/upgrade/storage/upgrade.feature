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

  # @author chaoyang@redhat.com
  #  @upgrade-prepare
  #@users=upuser1,upuser2
  @admin
  Scenario: Snapshot operator should be in available status after upgrade and can created pod with snapshot
    Given I switch to cluster admin pseudo user		
    When I run the :create admin command with:
      | f | <%= BushSlicer::HOME %>/testdata/storage/csi/aws-ebs-with-snapshots.yaml |
    Then the step should succeed
    When I use the "kube-system" project
    And I wait up to 180 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | deployment         |
      | name     | ebs-csi-controller |
    Then the output should match "1 desired.*1 updated.*1 total.*1 available.*0 unavailable"
    When I run the :describe client command with:
      | resource | daemonset    |
      | name     | ebs-csi-node |
    Then the output should match "0 Waiting.*0 Succeeded.*0 Failed"
    """

    #Create csi storage class and snapshot class
    Then I run the :create admin command with:
      | f | <%= BushSlicer::HOME %>/testdata/storage/csi/storageclass-ebs.yaml |
    Then the step should succeed
    Then I run the :create admin command with:
      | f | <%= BushSlicer::HOME %>/testdata/storage/csi/snapshotclass-ebs.yaml |
    Then the step should succeed

    #Create pvc, pod
    When I run the :new_project client command with:
      | project_name | upgrade-ocp-28630 |
    Then I use the "upgrade-ocp-28630" project
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc-with-storageClassName.json" replacing paths:
      | ["metadata"]["name"]         | pvc-ebs |
      | ["spec"]["storageClassName"] | sc-ebs  |
    Then the step should succeed
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/misc/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod     |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-ebs   |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/ebs  |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    
    When I execute on the pod:
      | touch | /mnt/ebs/test-before-upgrade |
    Then the step should succeed

    Then I execute on the pod:
      | sync |
    Then the step should succeed

    #Create volumesnapshot
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/csi/snapshot/volumesnapshot.yaml" replacing paths:
      | ["metadata"]["name"]                            | pvc-ebs-snapshot |
      | ["spec"]["volumeSnapshotClassName"]             | ebs-snap         |
      | ["spec"]["source"]["persistentVolumeClaimName"] | pvc-ebs          |
    Then the step should succeed
    And I wait up to 180 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | volumesnapshot   |
      | name     | pvc-ebs-snapshot |
    Then the output should match "Ready To Use\:\s+true"
    """

  # @author chaoyang@redhat.com
  # @case_id OCP-28630
  @upgrade-check
  @admin
  Scenario: Snapshot operator should be in available status after upgrade and can created pod with snapshot
    Given I switch to cluster admin pseudo user
    
    #Snapshot operator/controller update
    Given the "csi-snapshot-controller" operator version matchs the current cluster version
    Given the status of condition "Degraded" for "csi-snapshot-controller" operator is: False
    Given the status of condition "Progressing" for "csi-snapshot-controller" operator is: False
    Given the status of condition "Available" for "csi-snapshot-controller" operator is: True
    Given the status of condition "Upgradeable" for "csi-snapshot-controller" operator is: True

    #Restore works
    When I use the "upgrade-ocp-28630" project
    Then I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/csi/snapshot/restorepvc.yaml" replacing paths:
      | ["spec"]["storageClassName"]   | sc-ebs           |
      | ["spec"]["dataSource"]["name"] | pvc-ebs-snapshot | 
    Then the step should succeed

    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/misc/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-restore |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | restore-pvc   |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/ebs      |
    Given the pod named "mypod-restore" becomes ready

    When I execute on the pod:
      | ls | /mnt/ebs |
    Then the output should contain:
      | test-before-upgrade |
