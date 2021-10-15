Feature: oc_volume.feature

  # @author xxia@redhat.com
  # @author weinliu@redhat.com
  # @case_id OCP-12194
  @smoke
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
  Scenario: Create a pod that consumes the secret in a volume
    Given I have a project
    Given I obtain test data file "pods/allinone-volume/secret.yaml"
    Given I run the :create client command with:
      | f | secret.yaml |
    Then the step should succeed
    When I run the :secret_link client command with:
      | secret_name | test-secret |
      | sa_name     | default     |
    Then the step should succeed
    When I run the :new_app_as_dc client command with:
      | docker_image | quay.io/openshifttest/storage@sha256:a05b96d373be86f46e76817487027a7f5b8b5f87c0ac18a246b018df11529b40 |
      | name         | mydc                                                                                                  |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=mydc-1 |
    When I run the :set_volume client command with:
      | resource      | dc                     |
      | resource_name | mydc                   |
      | action        | --add                  |
      | name          | secret-volume          |
      | type          | secret                 |
      | secret-name   | test-secret            |
      | mount-path    | /etc/secret-volume-dir |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=mydc-2 |
    When I execute on the pod:
      | cat | /etc/secret-volume-dir/data-1 |
    Then the step should succeed
    And the output by order should contain:
      | value-1 |
    When I execute on the pod:
      | cat | /etc/secret-volume-dir/data-2 |
    Then the step should succeed
    And the output by order should contain:
      | value-2 |

  # @author xxia@redhat.com
  # @case_id OCP-11906
  @smoke
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
  Scenario: Add secret volume to dc and rc
    Given I have a project
    When I run the :new_app_as_dc client command with:
      | docker_image | quay.io/openshifttest/storage@sha256:a05b96d373be86f46e76817487027a7f5b8b5f87c0ac18a246b018df11529b40 |
      | name         | mydc                                                                                                  |
    Then the step should succeed
    When I run the :create_secret client command with:
      | secret_type | generic    |
      | name        | my-secret  |
      | from_file   | /etc/hosts |
    Then the step should succeed

    Given I wait until replicationController "mydc-1" is ready
    When I run the :set_volume client command with:
      | resource      | rc                |
      | resource_name | mydc-1            |
      | action        | --add             |
      | name          | secret            |
      | type          | secret            |
      | secret-name   | my-secret         |
      | mount-path    | /etc              |
    Then the step should succeed

    When I run the :set_volume client command with:
      | resource      | dc                |
      | resource_name | mydc              |
      | action        | --add             |
      | name          | secret            |
      | type          | secret            |
      | secret-name   | my-secret         |
      | mount-path    | /etc              |
    Then the step should succeed

    When I run the :get client command with:
      | resource | dc/mydc                              |
      | o        | custom-columns=volume:..volumeMounts |
    Then the step should succeed
    And the output should contain 1 times:
      | name:secret |

    When I run the :get client command with:
      | resource | rc/mydc-1                            |
      | o        | custom-columns=volume:..volumeMounts |
    Then the step should succeed
    And the output should contain 1 times:
      | name:secret |
