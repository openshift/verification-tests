Feature: Testing ipfailover scenarios

  # @author hongli@redhat.com
  # @case_id OCP-9767
  @admin
  @destructive
  Scenario: OCP-9767 Configure a highly available network service
    Given the cluster is running on OpenStack
    And I switch to cluster admin pseudo user
    And I use the "default" project
    And default router image is stored into the :router_image clipboard
    And SCC "privileged" is added to the "ipfailover" service account
    And admin ensures "ipf-9767" dc is deleted after scenario

    When I run the :oadm_ipfailover admin command with:
      | name        | ipf-9767                                                              |
      | images      | <%= cb.router_image.gsub("haproxy-router","keepalived-ipfailover") %> |
      | virtual_ips | 192.168.1.1                                                           |
      | watch_port  | 53                                                                    |
    Then a pod becomes ready with labels:
      | deploymentconfig=ipf-9767 |
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :logs admin command with:
      | resource_name | <%= pod.name %> |
      | namespace     | default         |
    Then the step should succeed
    And the output should contain:
      | Entering MASTER STATE |
    """
