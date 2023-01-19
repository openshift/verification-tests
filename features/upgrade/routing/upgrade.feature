Feature: Routing and DNS related scenarios

  @upgrade-prepare
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
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
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
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
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
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
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
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
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @baremetal-ipi
  @vsphere-upi @openstack-upi @baremetal-upi
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: upgrade with running router pods on all worker nodes - prepare
    # Get the number of worker nodes and scale up router pods
    Given I switch to cluster admin pseudo user
    And I store the number of linux worker nodes to the :num_workers clipboard
    And evaluation of `cb.num_workers - 1` is stored in the :num_routers clipboard
    When I run the :scale admin command with:
      | resource | ingresscontroller          |
      | name     | default                    |
      | replicas | <%= cb.num_routers %>      |
      | n        | openshift-ingress-operator |
    Then the step should succeed
    Given I use the "openshift-ingress" project
    And I wait up to 180 seconds for the steps to pass:
    """
    Then the expression should be true> deployment("router-default").current_replicas(cached: false) == <%= cb.num_routers %>
    And <%= cb.num_routers %> pods become ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default |
    """

  # @author hongli@redhat.com
  # @case_id OCP-30501
  @upgrade-check
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @baremetal-ipi
  @vsphere-upi @openstack-upi @baremetal-upi
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
  Scenario: upgrade with running router pods on all worker nodes
    Given I switch to cluster admin pseudo user
    And I store the number of linux worker nodes to the :num_workers clipboard
    And evaluation of `cb.num_workers - 1` is stored in the :num_routers clipboard
    Given I use the "openshift-ingress" project
    Then the expression should be true> deployment("router-default").current_replicas(cached: false) == <%= cb.num_routers %>
    And <%= cb.num_routers %> pods become ready with labels:
      | ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default |


  @upgrade-prepare
  @users=upuser1,upuser2
  @admin
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @gcp-ipi @azure-ipi
  @gcp-upi @azure-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
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
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @gcp-ipi @azure-ipi
  @gcp-upi @azure-upi
  @singlenode
  @proxy @noproxy @disconnected @connected
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @heterogeneous @arm64 @amd64
  @hypershift-hosted
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


  # @author mjoseph@redhat.com
  @upgrade-prepare
  @users=upuser1,upuser2
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @hypershift-hosted
  Scenario: Unidling a route work without user intervention - prepare
    Given I switch to first user
    And I run the :new_project client command with:
      | project_name | ocp45955 |
    Then the step should succeed
    When I use the "ocp45955" project
    Given I obtain test data file "routing/web-server-rc.yaml"
    Given I wait up to 30 seconds for the steps to pass:
    """
    When I run the :create client command with:
      | f | web-server-rc.yaml|
    Then the step should succeed
    """

    And a pod becomes ready with labels:
      | name=web-server-rc |
    Then evaluation of `pod.name` is stored in the :pod_name clipboard
    Then the expression should be true> service('service-unsecure').exists?
    When I expose the "service-unsecure" service
    Then the step should succeed

    When I wait for a web server to become available via the "service-unsecure" route
    And the output should contain "Hello-OpenShift"

    When I run the :idle client command with:
      | svc_name | service-unsecure |
    Then the step should succeed
    Given I wait for the resource "pod" named "<%= cb.pod_name %>" to disappear within 180 seconds

    # Check the servcie service-unsecure to see the idle annotation
    And the expression should be true> service('service-unsecure').annotation('idling.alpha.openshift.io/unidle-targets', cached: false) == "[{\"kind\":\"ReplicationController\",\"name\":\"web-server-rc\",\"replicas\":1}]"

  # @author mjoseph@redhat.com
  # @case_id OCP-45955
  @upgrade-check
  @users=upuser1,upuser2
  @4.13 @4.12 @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
  @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @hypershift-hosted
  Scenario: Unidling a route work without user intervention
    # Check the servcie service-unsecure to see the idle annotation is still intact
    Given I switch to first user
    Given I use the "ocp45955" project
    Given I wait up to 180 seconds for the steps to pass:
    """
    And the expression should be true> service('service-unsecure').annotation('idling.alpha.openshift.io/unidle-targets', cached: false) == "[{\"kind\":\"ReplicationController\",\"name\":\"web-server-rc\",\"replicas\":1}]"
    """

    Given I open web server via the "service-unsecure" route
    And I wait for a web server to become available via the "service-unsecure" route
    And the output should contain "Hello-OpenShift"

    # Check the servcie service-unsecure to see the idle annotation got removed
    And the expression should be true> !service('service-unsecure').annotation('idling.alpha.openshift.io/unidle-targets', cached: false)
