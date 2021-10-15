Feature: Routing and DNS related scenarios

  @upgrade-prepare
  @admin
  Scenario: ensure ingress works well before and after upgrade - prepare
    # Check console route
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    Given I run the steps 6 times:
    """
    When I open secure web server via the "console" route
    Then the step should succeed
    """

  # @author hongli@redhat.com
  # @case_id OCP-29746
  @upgrade-check
  @admin
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
  Scenario: ensure ingress works well before and after upgrade
    # Check console route after upgraded
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    Given I run the steps 6 times:
    """
    When I open secure web server via the "console" route
    Then the step should succeed
    """

  @upgrade-prepare
  @admin
  Scenario: ensure DNS works well before and after upgrade - prepare
    # Check service name can be resolvede
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    And I use the "console" service
    And evaluation of `service.ip` is stored in the :console_svc_ip clipboard
    Given I use the "openshift-ingress-operator" project
    And a pod becomes ready with labels:
      | name=ingress-operator |
    Given I execute on the pod:
      | nslookup | console.openshift-console.svc |
    Then the output should contain "<%= cb.console_svc_ip %>"

  # @author hongli@redhat.com
  # @case_id OCP-29747
  @upgrade-check
  @admin
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
  Scenario: ensure DNS works well before and after upgrade
    # Check service name can be resolvede
    Given I switch to cluster admin pseudo user
    And I use the "openshift-console" project
    And I use the "console" service
    And evaluation of `service.ip` is stored in the :console_svc_ip clipboard
    Given I use the "openshift-ingress-operator" project
    And a pod becomes ready with labels:
      | name=ingress-operator |
    Given I execute on the pod:
      | nslookup | console.openshift-console.svc |
    Then the output should contain "<%= cb.console_svc_ip %>"

  @upgrade-prepare
  @admin
  Scenario: upgrade with running router pods on all worker nodes - prepare
    # Get the number of worker nodes and scale up router pods
    Given I switch to cluster admin pseudo user
    And I store the number of worker nodes to the :num_workers clipboard
    When I run the :scale admin command with:
      | resource | ingresscontroller          |
      | name     | default                    |
      | replicas | <%= cb.num_workers %>      |
      | n        | openshift-ingress-operator |
    Then the step should succeed
    Given I use the "openshift-ingress" project
    And I wait up to 180 seconds for the steps to pass:
    """
    Then the expression should be true> deployment("router-default").current_replicas(cached: false) == <%= cb.num_workers %>
    And <%= cb.num_workers %> pods become ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default |
    """

  # @author hongli@redhat.com
  # @case_id OCP-30501
  @upgrade-check
  @admin
  @4.10 @4.9
  Scenario: upgrade with running router pods on all worker nodes
    Given I switch to cluster admin pseudo user
    And I store the number of worker nodes to the :num_workers clipboard
    Given I use the "openshift-ingress" project
    Then the expression should be true> deployment("router-default").current_replicas(cached: false) == <%= cb.num_workers %>
    And <%= cb.num_workers %> pods become ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default |


  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  Scenario: upgrade with route shards - prepare
    # Ensure cluster operator ingress is in normal status
    Given I switch to cluster admin pseudo user
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Degraded')['status'] == "False"
    # create project/namespace with the label 
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | ingress-upgrade |
    Then the step should succeed
    Given I use the "ingress-upgrade" project
    And I store default router subdomain in the :subdomain clipboard
    Given I obtain test data file "routing/web-server-rc.yaml"
    When I run the :create client command with:
      | f | web-server-rc.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.ip` is stored in the :pod_ip clipboard
    When I run the :create_route_edge client command with:
      | name     | route-edge                  |
      | hostname | ingress-upgrade.example.com |
      | service  | service-unsecure            |
    Then the step should succeed
    When I run the :label admin command with:
      | resource | namespace        |
      | name     | ingress-upgrade  |
      | key_val  | namespace=shards |
    Then the step should succeed

    # Get the default ingresscontroller's loadBalancer scope
    # And enable route shards by creating new ingresscontroller
    Given I switch to cluster admin pseudo user
    When I run the :get admin command with:
      | resource      | ingresscontroller                                         |
      | resource_name | default                                                   |
      | namespace     | openshift-ingress-operator                                |
      | template      | {{.status.endpointPublishingStrategy.loadBalancer.scope}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :default_lb_scope clipboard
    Given I obtain test data file "routing/operator/ingressctl-ns-shards.yaml"
    When I run oc create over "ingressctl-ns-shards.yaml" replacing paths:
      | ["spec"]["domain"]                                              | <%= cb.subdomain.gsub("apps","shards") %> |
      | ["spec"]["endpointPublishingStrategy"]["loadBalancer"]["scope"] | <%= cb.default_lb_scope  %>               |
    Then the step should succeed
    Given I use the "openshift-ingress" project
    And a pod becomes ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=shards |

    # ensure the route in the matched namespace is loaded
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | grep | <%= cb.pod_ip %> | haproxy.config |
    Then the step should succeed
    """
    # Ensure cluster operator ingress is in normal status
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Degraded')['status'] == "False"

  # @author hongli@redhat.com
  # @case_id OCP-38812
  @upgrade-check
  @users=upuser1,upuser2
  @admin
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @azure-ipi
  Scenario: upgrade with route shards
    # Ensure cluster operator ingress is in normal status after upgrade
    Given I switch to cluster admin pseudo user
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Available')['status'] == "True"
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Progressing')['status'] == "False"
    Given the expression should be true> cluster_operator('ingress').condition(type: 'Degraded')['status'] == "False"

    Given I use the "openshift-ingress" project
    And a pod becomes ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=shards |
    Then evaluation of `pod.ip` is stored in the :router_ip clipboard

    # Ensure the route served by shards is still accessible after upgrade
    Given I switch to the first user
    And I use the "ingress-upgrade" project
    And I have a pod-for-ping in the project
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -k | --resolve | ingress-upgrade.example.com:443:<%= cb.router_ip %> | https://ingress-upgrade.example.com |
    Then the step should succeed
    And the output should contain "Hello-OpenShift web-server-rc"
    """
