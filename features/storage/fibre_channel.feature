Feature: FibreChannel specific scenarios on dedicated servers
  # @author chaoyang@redhat.com
  # @case_id OCP-15499
  @admin
  @destructive
  Scenario: Drain a node that is filled with fibre channel volume mounts
    Given I have a project

    Given I store all worker nodes to the :all_workers clipboard
    Given I run commands on the nodes in the :all_workers clipboard:
      | /sbin/mpathconf --enable |
    Then the step should succeed

    Given I obtain test data file "storage/fibrechannel/storageclass.yaml"
    When admin creates a StorageClass from "storageclass.yaml" where:
      | ["metadata"]["name"]  | sc-<%= project.name %> |
    Then the step should succeed

    Given I obtain test data file "storage/fibrechannel/pv1.yaml"
    And admin creates a PV from "pv1.yaml" where:
      | ["metadata"]["name"]         | pv-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %> | 
    Then the step should succeed

    Given I obtain test data file "storage/fibrechannel/pvc1.yaml"
    When I create a dynamic pvc from "pvc1.yaml" replacing paths:
      | ["metadata"]["name"]         | pvc-<%= project.name %> |
      | ["spec"]["storageClassName"] | sc-<%= project.name %>  |
      | ["spec"]["volumeName"]       | pv-<%= project.name %>  |
    Then the step should succeed
    And the "pvc-<%= project.name %>" PVC becomes :bound within 120 seconds

    Given I obtain test data file "storage/fibrechannel/dc1.yaml"
    When I run oc create over "dc1.yaml" replacing paths:
      | ["spec"]["template"]["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | pvc-<%= project.name %> | 
    Then the step should succeed
    And a pod becomes ready with labels:
      | app=hello-storage | 
    
    #Saved the node which pod scheduled to
    When I run the :get client command with:
      | resource | pods |
      | o        | json |
    Then the step should succeed 
    And evaluation of `@result[:parsed]['items'][0]['spec']['nodeName']` is stored in the :node_befordrain clipboard

    Given I use the "<%= cb.node_befordrain %>" node
    And I run commands on the host:
      | multipath -ll |
    Then the output should contain:
      | dm-0 |
      | dm-1 |
    Then the step should succeed

    Given node schedulable status should be restored after scenario
    When I run the :oadm_drain admin command with:
      | node_name    | <%= cb.node_befordrain %> |
      | pod-selector | app=hello-storage         | 
      | force        | true                      |
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear

    Given I use the "<%= cb.node_befordrain %>" node
    When I run commands on the host:
      | dmesg |
    Then the output should not contain:
      | I/O error |	
    Then the step should succeed
    When I run commands on the host:
      | multipath -ll |  
    Then the output should contain 1 times:
      | dm | 
    Then the step should succeed

