Feature: storage security check

  # @author lxia@redhat.com
  @admin
  Scenario Outline: [origin_infra_20] volume security testing
    Given I have a project
    And I have a 1 GB volume and save volume id in the :vid clipboard

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/<type>/security/<type>-selinux-fsgroup-test.json" replacing paths:
      | ["metadata"]["name"]                                      | pod-<%= project.name %>                                                                               |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"] | /mnt                                                                                                  |
      | ["spec"]["containers"][0]["image"]                        | quay.io/openshifttest/storage@sha256:a05b96d373be86f46e76817487027a7f5b8b5f87c0ac18a246b018df11529b40 |
      | ["spec"]["securityContext"]["seLinuxOptions"]["level"]    | s0:c13,c2                                                                                             |
      | ["spec"]["securityContext"]["fsGroup"]                    | 24680                                                                                                 |
      | ["spec"]["securityContext"]["runAsUser"]                  | 1000160000                                                                                            |
      | ["spec"]["volumes"][0]["<storage_type>"]["<volume_name>"] | <%= cb.vid %>                                                                                         |
    Then the step should succeed
    And the pod named "pod-<%= project.name %>" becomes ready
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
    Given I ensure "pod-<%= project.name %>" pod is deleted

    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/<type>/security/<type>-privileged-test.json" replacing paths:
      | ["metadata"]["name"]                                      | pod2-<%= project.name %>                                                                              |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"] | /mnt                                                                                                  |
      | ["spec"]["containers"][0]["image"]                        | quay.io/openshifttest/storage@sha256:a05b96d373be86f46e76817487027a7f5b8b5f87c0ac18a246b018df11529b40 |
      | ["spec"]["securityContext"]["seLinuxOptions"]["level"]    | s0:c13,c2                                                                                             |
      | ["spec"]["securityContext"]["fsGroup"]                    | 24680                                                                                                 |
      | ["spec"]["volumes"][0]["<storage_type>"]["<volume_name>"] | <%= cb.vid %>                                                                                         |
    Then the step should succeed
    And the pod named "pod2-<%= project.name %>" becomes ready
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

    Examples:
      | storage_type         | volume_name | type   |
      | gcePersistentDisk    | pdName      | gce    | # @case_id OCP-9700
      | awsElasticBlockStore | volumeID    | ebs    | # @case_id OCP-9699
      | cinder               | volumeID    | cinder | # @case_id OCP-9721

  # @author chaoyang@redhat.com
  # @case_id OCP-9709
  @admin
  Scenario: OCP-9709 secret volume security check
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/storage/secret/secret.yaml |
    Then the step should succeed

    Given I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/storage/secret/secret-pod-test.json |
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

