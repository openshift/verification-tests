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
    # Now scale down CNO pod to 0 and makes sure dhcp pods still running and erase additionalnetworks config from CNO
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
    #A minimum wait for 10 seconds is tested to reflect CNO deployment to be effective which will then re-spawn ovn pods
    Given 10 seconds have passed
    And admin waits for all pods in the "openshift-ovn-kubernetes" project to become ready up to 60 seconds
    #Checking whether Kube API data is synced on OVN NB db which in this case is a test-pod created in earlier steps
    Given I store the ovnkube-master "north" leader pod in the clipboard
    And admin executes on the pod:
      | bash | -c | ovn-nbctl list logical_switch_port |
    Then the step should succeed
    And the output should contain:
      | hello-pod |
