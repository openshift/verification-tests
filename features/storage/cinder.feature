Feature: Cinder Persistent Volume

  # @author wehe@redhat.com
  # @case_id OCP-9643
  @admin
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @singlenode
  @proxy @noproxy @disconnected @connected
  @s390x @ppc64le @heterogeneous @arm64 @amd64
  @openstack-ipi
  @openstack-upi
  @hypershift-hosted
  @storage
  Scenario: OCP-9643:Storage Persistent Volume with cinder volume plugin
    Given I have a project
    And I have a 1 GB volume and save volume id in the :vid clipboard

    #create test pod
    And I switch to cluster admin pseudo user
    And I use the "<%= project.name %>" project
    Given I obtain test data file "storage/cinder/cinder-pod.yaml"
    When I run oc create over "cinder-pod.yaml" replacing paths:
      | ['spec']['volumes'][0]['cinder']['volumeID'] | <%= cb.vid %> |
    Then the step should succeed
    And the pod named "cinder" becomes ready

    #create test file
    Given I execute on the "cinder" pod:
      | touch | /mnt/cinderfile |
    Then the step should succeed
    When I execute on the "cinder" pod:
      | ls | -l | /mnt/cinderfile |
    Then the step should succeed

