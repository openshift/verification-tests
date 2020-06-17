Feature: OVN related networking scenarios

  # @author anusaxen@redhat.com
  # @case_id OCP-29954
  @admin
  @destructive
  Scenario: Creating a resource in Kube API should be synced to OVN NB db correctly even post NB db crash too
    Given the env is using "OVNKubernetes" networkType
    Given I have a project
    And I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1_name clipboard
    And evaluation of `pod(1).name` is stored in the :pod2_name clipboard
    #Checking whether Kube API data is synced on OVN NB db which in this case are couple of pods
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And evaluation of `pod.ip_url` is stored in the :ovn_nb_leader_ip clipboard
    And evaluation of `pod.node_name` is stored in the :ovn_nb_leader_node clipboard
    And admin executes on the pod:
      | bash | -c | ovn-nbctl list logical_switch_port |
    Then the step should succeed
    And the output should contain:
      | <%= cb.pod1_name %> |
      | <%= cb.pod2_name %> |
    #Simulating a NB db crash
    Given I use the "<%= cb.ovn_nb_leader_node %>" node
    And I run commands on the host:
      | pkill -f OVN_Northbound |
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 120 seconds
    #Making sure the pod entries are synced again when NB db is re-created
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And evaluation of `pod.ip_url` is stored in the :new_ovn_nb_leader_ip clipboard
    Given admin executes on the pod:
      | bash | -c | ovn-nbctl list logical_switch_port |
    Then the step should succeed
    And the output should contain:
      | <%= cb.pod1_name %> |
      | <%= cb.pod2_name %> |


  # @author anusaxen@redhat.com
  # @case_id OCP-30055
  @admin
  @destructive
  Scenario: OVN DB should be updated correctly if a resource only exist in Kube API but not in OVN NB db
    Given the env is using "OVNKubernetes" networkType
    # Now scale down CNO pod to 0
    Given admin uses the "openshift-network-operator" project
    And I run the :scale admin command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 0                |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given admin uses the "openshift-network-operator" project
    And I run the :scale admin command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 1                |
    Then the step should succeed
    """
    When I run the :delete admin command with:
      | object_type       | ds                       |
      | object_name_or_id | ovnkube-master           |
      | n                 | openshift-ovn-kubernetes |
    Then the step should succeed
    Given I have a project
    And I obtain test data file "networking/pod-for-ping.json"
    When I run the :create client command with:
      | f | pod-for-ping.json |
    Then the step should succeed
    #Now scale down CNO pod to 1 and check whether hello-pod is synced to NB db
    Given I run the :scale admin command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 1                |
    Then the step should succeed
    #A minimum wait for 30 seconds is tested to reflect CNO deployment to be effective which will then re-spawn ovn pods
    Given 30 seconds have passed
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds
    #Checking whether Kube API data is synced on OVN NB db which in this case is a test-pod created in earlier steps
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And admin executes on the pod:
      | bash | -c | ovn-nbctl list logical_switch_port |
    Then the step should succeed
    And the output should contain:
      | hello-pod |
  
  # @author anusaxen@redhat.com
  # @case_id OCP-30057
  @admin
  @destructive
  Scenario: OVN DB should be updated correctly if a resource only exist in NB db but not in Kube API	
    Given the env is using "OVNKubernetes" networkType
    Given I have a project
    And evaluation of `project.name` is stored in the :hello_pod_project clipboard
    And I have a pod-for-ping in the project
    #Checking whether Kube API data is synced on OVN NB db which in this case is a hello-pod created in earlier steps
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And admin executes on the pod:
      | bash | -c | ovn-nbctl list logical_switch_port |
    Then the step should succeed
    And the output should contain:
      | hello-pod |
    # Now scale down CNO pod to 0
    Given admin uses the "openshift-network-operator" project
    And I run the :scale admin command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 0                |
    Then the step should succeed
    Given I register clean-up steps:
    """
    Given admin uses the "openshift-network-operator" project
    And I run the :scale admin command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 1                |
    Then the step should succeed
    """
    When I run the :delete admin command with:
      | object_type       | ds                       |
      | object_name_or_id | ovnkube-master           |
      | n                 | openshift-ovn-kubernetes |
    Then the step should succeed
    And I ensures "hello-pod" pod is deleted from the "<%= cb.hello_pod_project %>" project
    #Now scale down CNO pod to 1 and check whether hello-pod status is synced to NB db means it should not present in the DB
    Given admin uses the "openshift-network-operator" project
    Given I run the :scale admin command with:
      | resource | deployment       |
      | name     | network-operator |
      | replicas | 1                |
    Then the step should succeed
    #A recommended wait for 30 seconds is tested to reflect CNO deployment to be in effect which will then re-spawn ovn pods
    Given 30 seconds have passed
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And admin executes on the pod:
      | bash | -c | ovn-nbctl list logical_switch_port |
    Then the step should succeed
    #making sure here that hello-pod absense is properly synced
    And the output should not contain:
      | hello-pod |
