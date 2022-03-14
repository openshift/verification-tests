Feature: storage security check

  # @author lxia@redhat.com
  # @author piqin@redhat.com
  @admin
  @smoke
  @4.10 @4.9
  Scenario Outline: [origin_infra_20] volume security testing
    Given I have a project
    Given I obtain test data file "storage/misc/pvc.json"
    When I run oc create over "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc1 |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pvc.json"
    When I run oc create over "pvc.json" replacing paths:
      | ["metadata"]["name"] | mypvc2 |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "storage/security/privileged-test.json"
    When I run oc create over "privileged-test.json" replacing paths:
      | ["metadata"]["name"]                                        | mypod                                                                                                 |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]   | /mnt                                                                                                  |
      | ["spec"]["containers"][0]["image"]                          | quay.io/openshifttest/hello-openshift@sha256:b1aabe8c8272f750ce757b6c4263a2712796297511e0c6df79144ee188933623 |
      | ["spec"]["securityContext"]["seLinuxOptions"]["level"]      | s0:c13,c2                                                                                             |
      | ["spec"]["securityContext"]["fsGroup"]                      | 24680                                                                                                 |
      | ["spec"]["securityContext"]["runAsUser"]                    | 1000160000                                                                                            |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"]| mypvc1                                                                                                |
    Then the step should succeed
    And the pod named "mypod" becomes ready
    When I execute on the pod:
      | id | -u |
    Then the step should succeed
    And the output should contain:
      | 1000160000 |
    When I execute on the pod:
      | id | -G |
    Then the step should succeed
    And the output should contain:
      | 24680 |
    When I execute on the pod:
      | ls | -lZd | /mnt |
    Then the step should succeed
    And the output should match:
      | 24680                                    |
      | (svirt_sandbox_file_t\|container_file_t) |
      | s0:c2,c13                                |
    When I execute on the pod:
      | touch | /mnt/testfile |
    Then the step should succeed
    When I execute on the pod:
      | ls | -lZ | /mnt/testfile |
    Then the step should succeed
    And the output should contain:
      | 24680 |
    When I execute on the pod:
      | cp | /hello | /mnt |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/hello |
    Then the step should succeed
    And the output should contain "Hello OpenShift Storage"
    Given I ensure "mypod" pod is deleted

    Given I obtain test data file "storage/security/privileged-test.json"
    When I run oc create over "privileged-test.json" replacing paths:
      | ["metadata"]["name"]                                        | mypod2                                                                                                |
      | ["spec"]["containers"][0]["image"]                          | quay.io/openshifttest/hello-openshift@sha256:b1aabe8c8272f750ce757b6c4263a2712796297511e0c6df79144ee188933623 |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]   | /mnt                                                                                                  |
      | ["spec"]["securityContext"]["seLinuxOptions"]["level"]      | s0:c13,c2                                                                                             |
      | ["spec"]["securityContext"]["fsGroup"]                      | 24680                                                                                                 |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"]| mypvc2                                                                                                |
    Then the step should succeed
    And the pod named "mypod2" becomes ready
    When I execute on the pod:
      | id |
    Then the step should succeed
    And the output should contain:
      | uid=0 |
    When I execute on the pod:
      | id | -G |
    Then the step should succeed
    And the output should contain:
      | 24680 |
    When I execute on the pod:
      | ls | -lZd | /mnt |
    Then the step should succeed
    And the output should contain:
      | 24680 |
    When I execute on the pod:
      | touch | /mnt/testfile |
    Then the step should succeed
    When I execute on the pod:
      | ls | -lZ | /mnt/testfile |
    Then the step should succeed
    And the output should match:
      | 24680                                    |
      | (svirt_sandbox_file_t\|container_file_t) |
      | s0:c2,c13                                |
    When I execute on the pod:
      | cp | /hello | /mnt |
    Then the step should succeed
    When I execute on the pod:
      | /mnt/hello |
    Then the step should succeed
    And the output should contain "Hello OpenShift Storage"

    # keep the parameters for 3.11 cases can be run.
    @gcp-ipi
    @gcp-upi
    Examples:
      | storage_type         | volume_name | type   |
      | gcePersistentDisk    | pdName      | gce    | # @case_id OCP-9700

    @aws-ipi
    @aws-upi
    Examples:
      | storage_type         | volume_name | type   |
      | awsElasticBlockStore | volumeID    | ebs    | # @case_id OCP-9699

    @openstack-ipi
    @openstack-upi
    @singlenode
    @disconnected @connected
    Examples:
      | storage_type         | volume_name | type   |
      | cinder               | volumeID    | cinder | # @case_id OCP-9721

  # @author chaoyang@redhat.com
  # @case_id OCP-9709
  @admin
  @smoke
  @4.10 @4.9 @4.8 @4.7
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @upgrade-sanity
  @singlenode
  @disconnected @connected
  Scenario: secret volume security check
    Given I have a project
    Given I obtain test data file "storage/secret/secret.yaml"
    When I run the :create client command with:
      | filename | secret.yaml |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "storage/secret/secret-pod-test.json"
    When I run the :create client command with:
      | filename | secret-pod-test.json |
    Then the step should succeed

    Given the pod named "secretpd" becomes ready
    When I execute on the pod:
      | id | -G |
    Then the step should succeed
    And the outputs should contain "123456"
    When I execute on the pod:
      | ls | -lZd | /mnt/secret/ |
    Then the step should succeed
    And the outputs should match:
      | 123456                                                        |
      | system_u:object_r:(svirt_sandbox_file_t\|container_file_t):s0 |
    When I execute on the pod:
      | touch | /mnt/secret/file |
    Then the step should fail
    And the outputs should contain "Read-only file system"

