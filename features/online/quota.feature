Feature: ONLY ONLINE Quota related scripts in this file

  # @author bingli@redhat.com
  # @case_id OCP-12700
  Scenario: OCP-12700 CRUD operation to the resource quota as project owner
    Given I have a project
    When I run the :describe client command with:
      | resource | rolebinding   |
      | name     | project-owner |
    Then the step should succeed
    And the output should match:
      | create\s*delete\s*get\s*list\s*patch\s*update\s*watch.+resourcequotas |
    Given I obtain test data file "quota/quota.yaml"
    When I run the :create client command with:
      | f | quota.yaml |
    Then the step should succeed
    And the output should contain:
      | resourcequota "quota" created |
    When I run the :new_app client command with:
      | template | mysql-persistent |
    Then the step should succeed
    And I run the :describe client command with:
      | resource | quota   |
      | name     | quota   |
    Then the step should succeed
    And the output should match:
      | cpu\s*80m\s*1                   |
      | memory\s*409Mi\s*750Mi          |
      | pods\s*1\s*10                   |
      | replicationcontrollers\s*1\s*10 |
      | resourcequotas\s*1\s*1          |
      | services\s*1\s*10               |
    Then I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | events |
    Then the step should succeed
    And the output should contain:
      | exceeded quota |
    """
    When I run the :patch client command with:
      | resource      | quota                                                                                                                                                                    |
      | resource_name | quota                                                                                                                                                                    |
      | p             | {"spec":{"hard":{"cpu":"4","memory":"8Gi","persistentvolumeclaims":"10","pods":"20","replicationcontrollers":"20","resourcequotas":"5","secrets":"20","services":"20"}}} |
    Then the step should succeed
    And the output should contain:
      | "quota" patched |
    Given a pod becomes ready with labels:
      | deployment=mysql-1 |
    Then I wait up to 30 seconds for the steps to pass:
    """
    When I run the :describe client command with:
      | resource | quota   |
      | name     | quota   |
    Then the step should succeed
    And the output should match:
      | cpu\s*80m\s*4                   |
      | memory\s*409Mi\s*8Gi            |
      | persistentvolumeclaims\s*1\s*10 |
      | pods\s*1\s*20                   |
      | replicationcontrollers\s*1\s*20 |
      | resourcequotas\s*1\s*5          |
      | secrets\s*10\s*20               |
      | services\s*1\s*20               |
    """
    When I run the :delete client command with:
      | object_type       | quota |
      | object_name_or_id | quota |
    Then the step should succeed
    And the output should contain:
      | resourcequota "quota" deleted |

  # @author yuwei@redhat.com
  # @case_id OCP-10291
  Scenario: OCP-10291 Can not create resource exceed the hard quota in appliedclusterresourcequota
    Given I have a project
    And evaluation of `BushSlicer::AppliedClusterResourceQuota.list(user: user, project: project)` is stored in the :acrq clipboard
    And evaluation of `cb.acrq.find{|o|o.name.end_with?("-compute")}` is stored in the :memory_crq clipboard
    And evaluation of `cb.acrq.find{|o|o.name.end_with?('-timebound')}` is stored in the :memory_terminate_crq clipboard
    And evaluation of `cb.acrq.find{|o|o.name.end_with?('-noncompute')}` is stored in the :storage_crq clipboard

    When I run the :new_app client command with:
      | template | nodejs-mongo-persistent |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | deployment=nodejs-mongo-persistent-1 |
    And a pod becomes ready with labels:
      | deployment=mongodb-1 |
    When I run the :run client command with:
      | name    | run-once-pod-1   |
      | image   | openshift/origin |
      | command | true             |
      | cmd     | sleep            |
      | cmd     | 60m              |
      | restart | Never            |
      | limits  | memory=1Gi       |
    Then the step should succeed
    And the expression should be true> cb.memory_crq.total_used(cached: false).memory_limit_raw == "1Gi"
    And the expression should be true> cb.storage_crq.total_used(cached: false).storage_requests_raw == "1Gi"
    And the expression should be true> cb.memory_terminate_crq.total_used(cached: false).memory_limit_raw == "1Gi"

    Given I create a new project
    Given I check that the "<%= cb.memory_crq.name %>" applied_cluster_resource_quota exists
    Then the expression should be true> applied_cluster_resource_quota.total_used.memory_limit_raw == "1Gi"
    Given I check that the "<%= cb.storage_crq.name %>" applied_cluster_resource_quota exists
    Then the expression should be true> applied_cluster_resource_quota.total_used.storage_requests_raw == "1Gi"
    Given I check that the "<%= cb.memory_terminate_crq.name %>" applied_cluster_resource_quota exists
    Then the expression should be true> applied_cluster_resource_quota.total_used.memory_limit_raw == "1Gi"

    Given I obtain test data file "online/hello-pod-limit.yaml"
    When I run oc create over "hello-pod-limit.yaml" replacing paths:
      | ["spec"]["containers"][0]["resources"]["limits"]["memory"] | 2Gi |
    And the step should fail
    And the output should contain "exceeded quota"

    When I run the :run client command with:
      | name    | run-once-pod-2   |
      | image   | openshift/origin |
      | command | true             |
      | cmd     | sleep            |
      | cmd     | 60m              |
      | restart | Never            |
      | limits  | memory=2Gi       |
    Then the step should fail
    And the output should contain "exceeded quota"

    Given I obtain test data file "online/pvc_storage.yaml"
    When I run the :create client command with:
      | f | pvc_storage.yaml |
    Then the step should fail
    And the output should contain "exceeded quota"
