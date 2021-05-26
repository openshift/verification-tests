Feature: CSI testing related feature

  # @author chaoyang@redhat.com
  # @case_id OCP-30787
  @admin
  Scenario: CSI images checking in stage and prod env
    Given the master version >= "4.4"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"
    When I run the :get admin command with:
      | resource | volumesnapshot |
    Then the output should contain "true"

  # @author chaoyang@redhat.com
  # @case_id OCP-31345
  @admin
  Scenario: CSI images checking in stage env in OCP4.3
    Given the master version == "4.3"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"

  # @author chaoyang@redhat.com
  # @case_id OCP-31346
  @admin
  Scenario: CSI images checking in stage env in OCP4.2
    Given the master version == "4.2"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    Given the pod named "my-csi-app" status becomes :running

  # @author chaoyang@redhat.com
  @admin
  Scenario Outline: Configure 'Retain' reclaim policy
    Given I have a project
    And admin clones storage class "sc-<%= project.name %>" from "<sc_name>" with:
      | ["metadata"]["name"] | sc-<%= project.name %>      |
      | ["reclaimPolicy"]    | Retain                      |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]                         | pvc-<%= project.name %> |
      | ["spec"]["storageClassName"]                 | sc-<%= project.name %>  |
      | ["spec"]["accessModes"][0]                   | ReadWriteOnce           |
      | ["spec"]["resources"]["requests"]["storage"] | 1Gi                     |
    Then the step should succeed

    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod                   |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/iaas               |
    Then the step should succeed
    Given the pod named "mypod" becomes ready

    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds
    And the expression should be true> pv(pvc.volume_name).reclaim_policy == "Retain"

    And I ensure "mypod" pod is deleted
    When I ensure "pvc-<%= project.name %>" pvc is deleted
    Then the PV becomes :released
    And admin ensures "<%= pvc.volume_name %>" pv is deleted

    Examples:
      | sc_name |
      | gp2-csi | # @case_id OCP-24575

