Feature: Egress compoment upgrade testing

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  @4.8 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Check egressfirewall is functional post upgrade - prepare
    Given I switch to cluster admin pseudo user
    And I run the :new_project client command with:
      | project_name | egressfw-upgrade1 |
    Then the step should succeed
    When I use the "egressfw-upgrade1" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard

    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -I | --connect-timeout | 5 | redhat.com |
    Then the step should succeed
    And the output should contain "HTTP/1.0"

    Given I save egress data file directory to the clipboard
    Given I obtain test data file "networking/<%= cb.cb_egress_directory %>/limit_policy.json"
    When I run the :create admin command with:
      | f | limit_policy.json   |
      | n | <%= project.name %> |
    Then the step should succeed

    And I wait up to 10 seconds for the steps to pass:
    """
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -I | --connect-timeout | 5 | redhat.com |
    Then the step should fail
    And the output should not contain "HTTP/1.0"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-44315
  @admin
  @upgrade-check
  @4.8 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @azure-upi @aws-upi
  Scenario: Check egressfirewall is functional post upgrade
    Given I switch to cluster admin pseudo user
    And I save egress type to the clipboard
    When I run the :get admin command with:
      | resource | <%= cb.cb_egress_type %>  |
      | n        | egressfw-upgrade1         |
      | o        | jsonpath={.items[*].spec} |
    Then the step should succeed
    And the output should contain:
      | 0.0.0.0/0 |
    Given I use the "egressfw-upgrade1" project
    Given status becomes :running of 1 pod labeled:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -I | --connect-timeout | 5 | redhat.com |
    Then the step should fail
    And the output should not contain "HTTP/1.0"

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  @4.8 @4.10 @4.9
  @vsphere-ipi
  @vsphere-upi
  Scenario: Check ovn egressip is functional post upgrade - prepare
    Given I switch to cluster admin pseudo user
    And I save ipecho url to the clipboard
    Given I select a random node's host
    And evaluation of `node.name` is stored in the :egress_node clipboard
    When I run the :label admin command with:
      | resource | node                               |
      | name     | <%= cb.egress_node %>              |
      | key_val  | k8s.ovn.org/egress-assignable=true |
    Then the step should succeed

    #Get unused IP as egress ip
    Given I store a random unused IP address from the reserved range to the clipboard

    #Create new namespace and pods in it
    When I run the :new_project client command with:
      | project_name | egressip-upgrade1 |
    Then the step should succeed
    When I use the "egressip-upgrade1" project
    When I run the :label admin command with:
      | resource | namespace           |
      | name     | egressip-upgrade1   |
      | key_val  | org=qe              |
    Then the step should succeed

    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod1 clipboard

    #Create egress ip object
    When I obtain test data file "networking/ovn-egressip/egressip1.yaml"
    And I replace lines in "egressip1.yaml":
      | 172.31.249.227 | "<%= cb.valid_ip %>" |
    And I run the :create admin command with:
      | f | egressip1.yaml |
    Then the step should succeed

    # Check source ip is egress ip
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

  # @author huirwang@redhat.com
  # @case_id OCP-44316
  @admin
  @upgrade-check
  @4.8 @4.10 @4.9
  @vsphere-ipi
  @vsphere-upi
  Scenario: Check ovn egressip is functional post upgrade
    Given I save ipecho url to the clipboard
    Given I switch to cluster admin pseudo user
    When I use the "egressip-upgrade1" project
    Given status becomes :running of 1 pod labeled:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard

    When I run the :get admin command with:
      | resource       | egressip                    |
      | resource_name  | egressip                    |
      | o              | jsonpath={.status.items[*]} |
    Then the step should succeed
    And evaluation of `@result[:response].chomp.match(/\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}/)` is stored in the :valid_ip clipboard
    When I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ip %>"

    # Remove label from egressip node and delete egress ip object
    Given admin ensures "egressip" egress_ip is deleted after scenario
    When I run the :get admin command with:
      | resource       | node                               |
      | l              | k8s.ovn.org/egress-assignable      |
      | o              | jsonpath={.items[*].metadata.name} |
    And evaluation of `@result[:response].chomp` is stored in the :egress_node clipboard
    When I run the :label admin command with:
      | resource | node                               |
      | name     | <%= cb.egress_node %>              |
      | key_val  | k8s.ovn.org/egress-assignable-     |
    Then the step should succeed

  # @author huirwang@redhat.com
  @admin
  @upgrade-prepare
  @4.10 @4.9
  Scenario: Check sdn egressip is functional post upgrade - prepare
    Given I save ipecho url to the clipboard
    Given I switch to cluster admin pseudo user
    Given I store the schedulable workers in the :workers clipboard
    Given I store a random unused IP address from the reserved range to the clipboard
    And evaluation of `lambda { |i| "#{i.to_s}/#{i.prefix.to_s}" }.call(IPAddr.new("<%= cb.subnet_range %>"))` is stored in the :valid_subnet clipboard

    #Patch two egress CIDRs to two nodes
    Given as admin I successfully merge patch resource "hostsubnet/<%= cb.workers[0].name %>" with:
      | {"egressCIDRs": ["<%= cb.valid_subnet %>"] }   |
    Given as admin I successfully merge patch resource "hostsubnet/<%= cb.workers[1].name %>" with:
      | {"egressCIDRs": ["<%= cb.valid_subnet %>"] }   |

    #Create two projects and pods
    When I run the :new_project client command with:
      | project_name | sdn-egressip-upgrade1 |
    Then the step should succeed
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    When I use the "sdn-egressip-upgrade1" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod1 clipboard

    When I run the :new_project client command with:
      | project_name | sdn-egressip-upgrade2 |
    Then the step should succeed
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    When I use the "sdn-egressip-upgrade2" project
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod(2).name` is stored in the :pod2 clipboard

    #Patch an egressip on each project
    Given as admin I successfully merge patch resource "netnamespace/sdn-egressip-upgrade1" with:
      | {"egressIPs": ["<%= cb.valid_ips[0] %>"]} |
    Given as admin I successfully merge patch resource "netnamespace/sdn-egressip-upgrade2" with:
      | {"egressIPs": ["<%= cb.valid_ips[1] %>"]} |

    #Check the source ip
    And I wait up to 30 seconds for the steps to pass:
    """
    When I use the "sdn-egressip-upgrade2" project
    And I execute on the "<%= cb.pod2 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ips[1] %>"
    When I use the "sdn-egressip-upgrade1" project
    And I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.valid_ips[0] %>"
    """

  # @author huirwang@redhat.com
  # @case_id OCP-45349
  @admin
  @upgrade-check
  @4.10 @4.9
  Scenario: Check sdn egressip is functional post upgrade
    Given I run the :get admin command with:
      | resource      | hostsubnet                                  |
      | o             | jsonpath={.items[?(@.egressCIDRs)].host}    |
    Then the step should succeed
    And evaluation of `@result[:response].split(" ")` is stored in the :egress_nodes clipboard
    And I register clean-up steps:
    """
    as admin I successfully merge patch resource "netnamespace/sdn-egressip-upgrade1" with:
      | {"egressIPs": null } |
    as admin I successfully merge patch resource "netnamespace/sdn-egressip-upgrade2" with:
      | {"egressIPs": null } |
    as admin I successfully merge patch resource "hostsubnet/<%= cb.egress_nodes[0] %>" with:
      | {"egressCIDRs":null,"egressIPs": null}   |
    as admin I successfully merge patch resource "hostsubnet/<%= cb.egress_nodes[1] %>" with:
      | {"egressCIDRs":null,"egressIPs": null}   |
    """

    Given I save ipecho url to the clipboard
    Given I switch to cluster admin pseudo user

    #Get configured EgressIPs
    When I run the :get admin command with:
      | resource       | netnamespace             |
      | resource_name  | sdn-egressip-upgrade1    |
      | o              | jsonpath={.egressIPs[0]} |
    And evaluation of `@result[:response].chomp` is stored in the :egress_ip1 clipboard
    When I run the :get admin command with:
      | resource       | netnamespace             |
      | resource_name  | sdn-egressip-upgrade2    |
      | o              | jsonpath={.egressIPs[0]} |
    And evaluation of `@result[:response].chomp` is stored in the :egress_ip2 clipboard

    When I use the "sdn-egressip-upgrade1" project
    Given status becomes :running of 1 pod labeled:
      | name=test-pods |
    And evaluation of `pod(0).name` is stored in the :pod1 clipboard
    And I execute on the "<%= cb.pod1 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.egress_ip1 %>"

    When I use the "sdn-egressip-upgrade2" project
    Given status becomes :running of 1 pod labeled:
      | name=test-pods |
    And evaluation of `pod(1).name` is stored in the :pod2 clipboard
    And I execute on the "<%= cb.pod2 %>" pod:
      | curl | -s | --connect-timeout | 5 | <%= cb.ipecho_url %> |
    Then the step should succeed
    And the output should contain "<%= cb.egress_ip2 %>"
