Feature: F5 router related scenarios

  # @author hongli@redhat.com
  # @case_id OCP-24080
  @admin
  @destructive
  Scenario: OCP-24080 the f5 router image should contains openssh-clients package
    Given I switch to cluster admin pseudo user
    And I use the router project
    And default router image is stored into the :router_image clipboard
    And default router replica count is restored after scenario
    When I run the :scale client command with:
      | resource | dc     |
      | name     | router |
      | replicas | 0      |
    Then the step should succeed
    Given admin ensures "f5router" dc is deleted after scenario
    And admin ensures "f5router" service is deleted after scenario
    And admin ensures "external-host-private-key-secret" secret is deleted after scenario
    And I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/routing/fake_id_rsa"
    When I run the :oadm_router admin command with:
      | name                      | f5router                                    |
      | type                      | f5-router                                   |
      | images                    | <%= cb.router_image.gsub("haproxy","f5") %> |
      | external_host             | 10.66.144.115                               |
      | external_host_username    | username                                    |
      | external_host_password    | password                                    |
      | external_host_private_key | fake_id_rsa                                 |
    And a pod becomes ready with labels:
      | deploymentconfig=f5router |
    When I execute on the pod:
      | which | scp |
    Then the step should succeed
