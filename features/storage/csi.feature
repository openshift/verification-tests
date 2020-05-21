Feature: CSI testing related feature

  # @author wehe@redhat.com
  # @case_id OCP-21804
  @admin
  @destructive
  Scenario: Deploy a cinder csi driver and test
    Given I deploy "cinder" driver using csi
    And I register clean-up steps:
    """
    I cleanup "cinder" csi driver
    """
    And I create storage class for "cinder" csi driver
    And I checked "cinder" csi driver is running
    And I have a project
    When I create a dynamic pvc from "<%= BushSlicer::HOME %>/testdata/storage/misc/pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc |
      | ["spec"]["storageClassName"] | cinder-csi              |
    Then the step should succeed
    And the "mypvc" PVC becomes :bound
    When I run oc create over "<%= BushSlicer::HOME %>/testdata/storage/misc/pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/cinder             |
    Then the step should succeed
    Given the pod named "mypod" becomes ready
    When I execute on the pod:
      | ls | -ld | /mnt/cinder/ |
    Then the step should succeed
    When I execute on the pod:
      | touch | /mnt/cinder/testfile |
    Then the step should succeed
    When I execute on the pod:
      | cp | /hello | /mnt/cinder/ |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/cinder/hello |
    Then the step should succeed
    And the output should contain "Hello OpenShift Storage"

  # @author chaoyang@redhat.com
  # @case_id OCP-30787
  @admin
  Scenario: CSI images checking in stage env
    Given the master version >= "4.4"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    When I run the :get admin command with:
      | resource | pods/my-csi-app |
    And the output should contain "Running"
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"
    When I run the :get admin command with:
      | resource | volumesnapshot |
    Then the output should contain "true"

  # @author chaoyang@redhat.com
  # @case_id OCP-31345
  @admin
  Scenario: CSI images checking in stage env in OCP4.3
    Given the master version >= "4.3"
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    When I run the :get admin command with:
      | resource | pods/my-csi-app |
    And the output should contain "Running"
    And the expression should be true> pvc("csi-pvc").capacity(cached: false) == "2Gi"

  # @author chaoyang@redhat.com
  # @case_id OCP-31346
  @admin  
  Scenario: CSI images checking in stage env in OCP4.2
    Given I switch to cluster admin pseudo user
    Given admin uses the "csihostpath" project
    When I run the :get admin command with:
      | resource | pods/my-csi-app |
    And the output should contain "Running" 
