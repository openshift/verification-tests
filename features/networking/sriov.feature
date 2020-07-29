Feature: Sriov related scenarios

  # @author zzhao@redhat.com
  # @case_id OCP-29944
  @admin
  Scenario: sriov operator can be setup and running well
    Given I switch to cluster admin pseudo user
    And I use the "openshift-sriov-network-operator" project
    And all existing pods are ready with labels:
      | app=network-resources-injector  |
    And all existing pods are ready with labels:
      | app=operator-webhook            |
    And all existing pods are ready with labels:
      | app=sriov-network-config-daemon |
    And status becomes :running of exactly 1 pods labeled:
      | name=sriov-network-operator     |


  # @author zzhao@redhat.com
  # @case_id OCP-24702
  @destructive
  @admin
  Scenario: netdevice VF for XXV710 can be worked well when sriovnetworknodepolicies is created for rhcos node
    Given the sriov operator is running well
    Given I obtain test data file "networking/sriov/sriovnetworkpolicy/intel-netdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | intel-netdevice.yaml     |
       | cr_name       | intel-netdevice          |
       | resource_type | sriovnetworknodepolicies |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource    | sriovnetworknodestates           |
      | namespace   | openshift-sriov-network-operator |
      | o           | yaml                             |
    Then the step should succeed
    And the output should contain "intel-netdevice"
    And the output should contain "syncStatus: Succeeded"
    And the output should contain "vfID: 4"
    """
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/static-sriovnetwork.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | static-sriovnetwork.yaml |
       | cr_name       | static-sriovnetwork      |
       | resource_type | sriovnetwork             |
       | project       | <%= cb.usr_project%>     |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project%>  |
    Then the step should succeed
    And the output should contain "static-sriovnetwork"
    """ 
    Given I switch to the first user
    And I use the "<%= cb.usr_project%>" project
    Given I obtain test data file "networking/sriov/pod/sriov-without-resource-static.yaml"
    When I run the :create client command with:
      | f | sriov-without-resource-static.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=sriov-static |
    When I execute on the pod:
      | bash | -c | /usr/sbin/ip addr show net1 |
    Then the output should contain "192.168.2.206"
    And the output should contain "2001::2/64"

  # @author zzhao@redhat.com
  # @case_id OCP-21364
  @destructive
  @admin  
  Scenario: Create pod with sriov-cni plugin and macvlan on the same interface
    Given the sriov operator is running well
    Given I obtain test data file "networking/sriov/sriovnetworkpolicy/intel-netdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | intel-netdevice.yaml     |
       | cr_name       | intel-netdevice          |
       | resource_type | sriovnetworknodepolicies |
    Then the step should succeed
    And I wait up to 300 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource    | sriovnetworknodestates           |
      | namespace   | openshift-sriov-network-operator |
      | o           | yaml                             |
    Then the step should succeed
    And the output should contain "intel-netdevice"
    And the output should contain "syncStatus: Succeeded"
    And the output should contain "vfID: 4"
    """
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/intelnetdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | intelnetdevice.yaml   |
       | cr_name       | intel-netdevice-rhcos |
       | resource_type | sriovnetwork          |
       | project       | <%= cb.usr_project%>  |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project%>  |
    Then the step should succeed
    And the output should contain "intel-netdevice-rhcos"
    """
    Given I switch to the first user
    And I use the "<%= cb.usr_project%>" project
    Given I obtain test data file "networking/multus-cni/NetworkAttachmentDefinitions/macvlan-conf-without-master.yaml"
    When I run the :create admin command with:
      | f         | macvlan-conf-without-master.yaml |
      | namespace | <%= cb.usr_project %>            |
    Then the step should succeed
    #When I run oc create as admin over "macvlan-conf-without-master.yaml" replacing paths:
    #  | ["metadata"]["namespace"] | <%= cb.usr_project %>
    #Then the step should succeed    
    Given I obtain test data file "networking/sriov/pod/sriov-macvlan.yaml"
    When I run the :create client command with:
      | f | sriov-macvlan.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=sriov-macvlan |
    When I execute on the pod:
      | /usr/sbin/ip | -d | link |
    Then the output should contain "net1"
    Then the output should contain "net2"

  # @author zzhao@redhat.com
  # @case_id OCP-24713
  @admin  
  @destructive
  Scenario: NAD can be also updated when networknamespace is change
    Given the sriov operator is running well
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project1 clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/intelnetdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | intelnetdevice.yaml   |
       | cr_name       | intel-netdevice-rhcos |
       | resource_type | sriovnetwork          |
       | project       | <%= cb.usr_project1%> |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project1%> |
    Then the step should succeed
    And the output should contain "intel-netdevice-rhcos"
    """
    Given I switch to the first user
    Given I create a new project
    And evaluation of `project.name` is stored in the :usr_project2 clipboard
    When I run the :patch admin command with:
      | resource      | sriovnetworks.sriovnetwork.openshift.io               |
      | resource_name | intel-netdevice-rhcos                                 |
      | p             | {"spec":{"networkNamespace":"<%= cb.usr_project2%>"}} |
      | type          | merge                                                 |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project1%> |
    Then the step should succeed
    And the output should not contain "intel-netdevice-rhcos"
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project2%> |
    Then the step should succeed
    And the output should contain "intel-netdevice-rhcos"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-24774
  @destructive
  @admin
  Scenario: VF for MT27710 can be worked well when sriovnetworknodepolicies is created for rhcos node
    Given the sriov operator is running well
    Given I obtain test data file "networking/sriov/sriovnetworkpolicy/mlx277-netdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | mlx277-netdevice.yaml    |
       | cr_name       | mlx277-netdevice         |
       | resource_type | sriovnetworknodepolicies |
    Then the step should succeed
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource    | sriovnetworknodestates           |
      | namespace   | openshift-sriov-network-operator |
      | o           | yaml                             |
    Then the step should succeed
    And the output should contain "mlx277-netdevice"
    And the output should contain "syncStatus: Succeeded"
    And the output should contain "vfID: 1"
    """
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/mlx277netdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | mlx277netdevice.yaml |
       | cr_name       | mlx277-netdevice     |
       | resource_type | sriovnetwork         |
       | project       | <%= cb.usr_project%> |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project%>  |
    Then the step should succeed
    And the output should contain "mlx277-netdevice"
    """
    Given I switch to the first user
    And I use the "<%= cb.usr_project%>" project
    Given I obtain test data file "networking/sriov/pod/sriov-macvlan.yaml"
    When I run oc create over "sriov-macvlan.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | mlx277-netdevice |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=sriov-macvlan |
    When I execute on the pod:
      | /usr/sbin/ip | a |
    Then the output should contain:
      | 10.56.217 |

  # @author zzhao@redhat.com
  # @case_id OCP-24780
  @admin  
  @destructive
  Scenario: NAD will be deleted too when sriovnetwork is deleted
    Given the sriov operator is running well
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project1 clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/intelnetdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | intelnetdevice.yaml   |
       | cr_name       | intel-netdevice-rhcos |
       | resource_type | sriovnetwork          |
       | project       | <%= cb.usr_project1%> |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project1%> |
    Then the step should succeed
    And the output should contain "intel-netdevice-rhcos"
    """
    Given I delete the "intel-netdevice-rhcos" sriovnetwork
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project1%> |
    Then the step should succeed
    And the output should not contain "intel-netdevice-rhcos"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-25287
  @admin  
  @destructive
  Scenario: NAD should be able to restore by sriov operator when it was deleted
    Given the sriov operator is running well
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project1 clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/intelnetdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | intelnetdevice.yaml   |
       | cr_name       | intel-netdevice-rhcos |
       | resource_type | sriovnetwork          |
       | project       | <%= cb.usr_project1%> |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project1%> |
    Then the step should succeed
    And the output should contain "intel-netdevice-rhcos"
    """
    When I run the :delete admin command with:
      | object_type       | net-attach-def        |
      | object_name_or_id | intel-netdevice-rhcos |
      | namespace         | <%= cb.usr_project1%> |
    Then the step should succeed
    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project1%> |
    Then the step should succeed
    And the output should contain "intel-netdevice-rhcos"
    """

  # @author zzhao@redhat.com
  # @case_id OCP-25790
  @admin  
  @destructive
  Scenario: SR-IOV network config daemon can be set by nodeselector
    Given the sriov operator is running well
    And all existing pods are ready with labels:
      | app=sriov-network-config-daemon |
    Given configDaemonNodeSelector set to false in sriovoperatorconfig
    And I wait for the resource "pod" named "<%= pod.name %>" to disappear within 120 seconds
    Given configDaemonNodeSelector set to true in sriovoperatorconfig
    Then all existing pods are ready with labels:
      | app=sriov-network-config-daemon |

  # @author zzhao@redhat.com
  # @case_id OCP-26134
  @admin
  @destructive
  Scenario: sriov can be shown in Metrics and telemetry
    Given the sriov operator is running well
    Given I obtain test data file "networking/sriov/sriovnetworkpolicy/mlx277-netdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | mlx277-netdevice.yaml    |
       | cr_name       | mlx277-netdevice         |
       | resource_type | sriovnetworknodepolicies |
    Then the step should succeed
    And I wait up to 500 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource    | sriovnetworknodestates           |
      | namespace   | openshift-sriov-network-operator |
      | o           | yaml                             |
    Then the step should succeed
    And the output should contain "mlx277-netdevice"
    And the output should contain "syncStatus: Succeeded"
    And the output should contain "vfID: 1"
    """
    Given I switch to the first user
    And I have a project
    And evaluation of `project.name` is stored in the :usr_project clipboard
    Given I obtain test data file "networking/sriov/sriovnetwork/mlx277netdevice.yaml"
    Given I create sriov resource with following:
       | cr_yaml       | mlx277netdevice.yaml |
       | cr_name       | mlx277-netdevice     |
       | resource_type | sriovnetwork         |
       | project       | <%= cb.usr_project%> |
    Then the step should succeed

    And I wait up to 30 seconds for the steps to pass:
    """
    When I run the :get admin command with:
      | resource  | net-attach-def        |
      | namespace | <%= cb.usr_project%>  |
    Then the step should succeed
    And the output should contain "mlx277-netdevice"
    """
    Given I switch to the first user
    And I use the "<%= cb.usr_project%>" project
    Given I obtain test data file "networking/sriov/pod/sriov-macvlan.yaml"
    When I run oc create over "sriov-macvlan.yaml" replacing paths:
      | ["metadata"]["annotations"]["k8s.v1.cni.cncf.io/networks"] | mlx277-netdevice |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=sriov-macvlan |
    And evaluation of `pod.name` is stored in the :pod_name clipboard

    Given I switch to cluster admin pseudo user
    Given admin uses the "openshift-multus" project
    When evaluation of `endpoints('multus-admission-controller').subsets.first.addresses.first.ip.to_s` is stored in the :mac_ip clipboard
    Given admin uses the "openshift-monitoring" project
    When evaluation of `secret(service_account('prometheus-k8s').get_secret_names.find {|s| s.match('token')}).token` is stored in the :sa_token clipboard

    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | sh                   |
      | exec_command_arg | -c                   |
      | exec_command_arg | curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://<%= cb.mac_ip %>:8443/metrics |
    Then the step should succeed
    And the output should contain:
      | network_attachment_definition_enabled_instance_up{networks="any"} 1   |
      | network_attachment_definition_enabled_instance_up{networks="sriov"} 1 |
      | network_attachment_definition_instances{networks="any"} 1             |
      | network_attachment_definition_instances{networks="sriov"} 1           |

    Given I switch to the first user
    Given I ensure "<%= cb.pod_name%>" pod is deleted from the "<%= cb.usr_project%>" project

    When I run the :exec admin command with:
      | n                | openshift-monitoring |
      | pod              | prometheus-k8s-0     |
      | c                | prometheus           |
      | oc_opts_end      |                      |
      | exec_command     | sh                   |
      | exec_command_arg | -c                   |
      | exec_command_arg | curl -k -H "Authorization: Bearer <%= cb.sa_token %>" https://<%= cb.mac_ip %>:8443/metrics |
    Then the step should succeed
    And the output should contain:
      | network_attachment_definition_enabled_instance_up{networks="any"} 0   |
      | network_attachment_definition_enabled_instance_up{networks="sriov"} 0 |
      | network_attachment_definition_instances{networks="any"} 0             |
      | network_attachment_definition_instances{networks="sriov"} 0           |
