Feature: networking isolation related scenarios

  # @author bmeng@redhat.com
  # @case_id OCP-9565
  @admin
  Scenario: The pods in default namespace can communicate with all the other pods
    Given I have a project
    And evaluation of `project.name` is stored in the :u1p1 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    Then evaluation of `pod.ip` is stored in the :u1p1pod_ip clipboard
    And evaluation of `pod.name` is stored in the :u1p1pod_name clipboard
    And evaluation of `service("test-service").ip(user: user)` is stored in the :u1p1svc_ip clipboard

    Given I create a new project
    And evaluation of `project.name` is stored in the :u1p2 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    Then evaluation of `pod.ip` is stored in the :u1p2pod_ip clipboard
    And evaluation of `pod.name` is stored in the :u1p2pod_name clipboard
    And evaluation of `service("test-service").ip(user: user)` is stored in the :u1p2svc_ip clipboard

    Given I switch to cluster admin pseudo user
    And I use the "default" project
    And evaluation of `rand_str(5, :dns952)` is stored in the :default_name clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | <%= cb.default_name %> |
      | ["items"][1]["metadata"]["name"] | <%= cb.default_name %> |
    Then the step should succeed
    And I register clean-up steps:
    """
    I run the :delete admin command with:
      | object_type | rc |
      | object_name_or_id | <%= cb.default_name %> |
    the step should succeed
    I run the :delete admin command with:
      | object_type | service |
      | object_name_or_id | <%= cb.default_name %> |
    the step should succeed
    """
    Given a pod becomes ready with labels:
      | name=test-pods |
    Then evaluation of `pod.ip` is stored in the :defaultpod_ip clipboard
    And evaluation of `pod.name` is stored in the :defaultpod_name clipboard
    And evaluation of `service("<%= cb.default_name %>").ip(user: user)` is stored in the :defaultsvc_ip clipboard

    When I execute on the "<%= cb.defaultpod_name %>" pod:
      | /usr/bin/curl | <%= cb.u1p1pod_ip %>:8080 |
    Then the output should contain "Hello OpenShift!"
    When I execute on the "<%= cb.defaultpod_name %>" pod:
      | /usr/bin/curl | <%= cb.u1p2pod_ip %>:8080 |
    Then the output should contain "Hello OpenShift!"
    When I execute on the "<%= cb.defaultpod_name %>" pod:
      | /usr/bin/curl | <%= cb.u1p1svc_ip %>:27017 |
    Then the output should contain "Hello OpenShift!"
    When I execute on the "<%= cb.defaultpod_name %>" pod:
      | /usr/bin/curl | <%= cb.u1p2svc_ip %>:27017 |
    Then the output should contain "Hello OpenShift!"

    Given I switch to the first user
    And I use the "<%= cb.u1p1 %>" project
    When I execute on the "<%= cb.u1p1pod_name %>" pod:
      | /usr/bin/curl | <%= cb.defaultpod_ip %>:8080 |
    Then the output should contain "Hello OpenShift!"
    When I execute on the "<%= cb.u1p1pod_name %>" pod:
      | /usr/bin/curl | <%= cb.defaultsvc_ip %>:27017 |
    Then the output should contain "Hello OpenShift!"

    Given I use the "<%= cb.u1p2 %>" project
    When I execute on the "<%= cb.u1p2pod_name %>" pod:
      | /usr/bin/curl | <%= cb.defaultpod_ip %>:8080 |
    Then the output should contain "Hello OpenShift!"
    When I execute on the "<%= cb.u1p2pod_name %>" pod:
      | /usr/bin/curl | <%= cb.defaultsvc_ip %>:27017 |
    Then the output should contain "Hello OpenShift!"

  # @author bmeng@redhat.com
  # @case_id OCP-9564
  @admin
  Scenario: Only the pods nested in a same namespace can communicate with each other
    Given the env is using multitenant network
    Given I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `@pods[0].ip` is stored in the :pr1ip0 clipboard
    And evaluation of `@pods[1].ip` is stored in the :pr1ip1 clipboard
    And evaluation of `@pods[0].name` is stored in the :pr1pod0 clipboard

    Given I switch to the second user
    And I have a project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run the :create client command with:
      | f | list_for_pods.json |
    Then the step should succeed
    Given 2 pods become ready with labels:
      | name=test-pods |
    And evaluation of `@pods[2].ip` is stored in the :pr2ip0 clipboard
    And evaluation of `@pods[3].ip` is stored in the :pr2ip1 clipboard

    Given I switch to the first user
    And I use the "<%= @projects[0].name %>" project
    When I execute on the "<%= cb.pr1pod0 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pr1ip1 %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.pr1pod0 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pr2ip1 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.pr1pod0 %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.pr2ip0 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"

  # @author bmeng@redhat.com
  # @case_id OCP-9641
  @admin
  Scenario: Make the network of given project be accessible to other projects
    # Create 3 projects and each contains 1 pod and 1 service
    Given the env is using multitenant network
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.ip` is stored in the :proj1p1 clipboard
    And evaluation of `pod.name` is stored in the :proj1p1name clipboard
    And evaluation of `service("test-service-1").ip(user: user)` is stored in the :proj1s1 clipboard

    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.ip` is stored in the :proj2p1 clipboard
    And evaluation of `service("test-service-2").ip(user: user)` is stored in the :proj2s1 clipboard

    Given I create a new project
    And evaluation of `project.name` is stored in the :proj3 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-3 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.ip` is stored in the :proj3p1 clipboard
    And evaluation of `service("test-service-3").ip(user: user)` is stored in the :proj3s1 clipboard

    # Merge the network of project 1 and 2, and check the netid
    When I run the :oadm_pod_network_join_projects admin command with:
      | project | <%= cb.proj1 %> |
      | to | <%= cb.proj2 %> |
    Then the step should succeed
    When I run the :get admin command with:
      | resource | netnamespace |
      | resource_name | <%= cb.proj1 %> |
      | template | {{.netid}} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :proj1netid clipboard
    When I run the :get admin command with:
      | resource | netnamespace |
      | resource_name | <%= cb.proj2 %> |
      | template | {{.netid}} |
    Then the step should succeed
    And the output should equal "<%= cb.proj1netid %>"

    # Create another new pod and service in each project
    Given I use the "<%= cb.proj1 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.ip` is stored in the :proj1p2 clipboard
    And evaluation of `service("new-test-service-1").ip(user: user)` is stored in the :proj1s2 clipboard

    Given I use the "<%= cb.proj2 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.ip` is stored in the :proj2p2 clipboard
    And evaluation of `pod.name` is stored in the :proj2p2name clipboard
    And evaluation of `service("new-test-service-2").ip(user: user)` is stored in the :proj2s2 clipboard

    Given I use the "<%= cb.proj3 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-3 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.ip` is stored in the :proj3p2 clipboard
    And evaluation of `pod.name` is stored in the :proj3p2name clipboard
    And evaluation of `service("new-test-service-3").ip(user: user)` is stored in the :proj3s2 clipboard

    # Access the pod/svc on other projects from project 1
    Given I use the "<%= cb.proj1 %>" project
    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj2p2 %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj3p1 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"

    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj2s1 %>:27017 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj3s2 %>:27017 |
    Then the step should fail
    And the output should not contain "Hello"

    # Access the pod/svc on other projects from project 2
    Given I use the "<%= cb.proj2 %>" project
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1p1 %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj3p2 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1s2 %>:27017 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj3s1 %>:27017 |
    Then the step should fail
    And the output should not contain "Hello"

    # Access the pod/svc on other projects from project 3
    Given I use the "<%= cb.proj3 %>" project
    When I execute on the "<%= cb.proj3p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1p2 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.proj3p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj2s1 %>:27017 |
    Then the step should fail
    And the output should not contain "Hello"

  # @author bmeng@redhat.com
  # @case_id OCP-12659
  @admin
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @aws-upi
  Scenario: Make the network of given projects be accessible globally
    # Create 3 projects and each contains 1 pod and 1 service
    Given the env is using multitenant network
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.ip` is stored in the :proj1p1 clipboard
    And evaluation of `pod.name` is stored in the :proj1p1name clipboard
    And evaluation of `service("test-service-1").ip(user: user)` is stored in the :proj1s1 clipboard

    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.ip` is stored in the :proj2p1 clipboard
    And evaluation of `service("test-service-2").ip(user: user)` is stored in the :proj2s1 clipboard

    Given I create a new project
    And evaluation of `project.name` is stored in the :proj3 clipboard
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-3 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.ip` is stored in the :proj3p1 clipboard
    And evaluation of `service("test-service-3").ip(user: user)` is stored in the :proj3s1 clipboard

    # Make the network of specific project global, and check the netid
    When I run the :oadm_pod_network_make_projects_global admin command with:
      | project | <%= cb.proj2 %> |
    Then the step should succeed
    When I run the :get admin command with:
      | resource | netnamespace |
      | resource_name | <%= cb.proj2 %> |
      | template | {{.netid}} |
    Then the step should succeed
    And the output should equal "0"

    # Create another new pod and service in each project
    Given I use the "<%= cb.proj1 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.ip` is stored in the :proj1p2 clipboard
    And evaluation of `service("new-test-service-1").ip(user: user)` is stored in the :proj1s2 clipboard

    Given I use the "<%= cb.proj2 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.ip` is stored in the :proj2p2 clipboard
    And evaluation of `pod.name` is stored in the :proj2p2name clipboard
    And evaluation of `service("new-test-service-2").ip(user: user)` is stored in the :proj2s2 clipboard

    Given I use the "<%= cb.proj3 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-3 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.ip` is stored in the :proj3p2 clipboard
    And evaluation of `pod.name` is stored in the :proj3p2name clipboard
    And evaluation of `service("new-test-service-3").ip(user: user)` is stored in the :proj3s2 clipboard

    # Access the pod/svc on other projects from project 1
    Given I use the "<%= cb.proj1 %>" project
    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj2p2 %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj3s1 %>:27017 |
    Then the step should fail
    And the output should not contain "Hello"
    # Access the pod/svc on other projects from project 2
    Given I use the "<%= cb.proj2 %>" project
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1s2 %>:27017 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj3p2 %>:8080 |
    Then the step should succeed
    And the output should contain "Hello"
    # Access the pod/svc on other projects from project 3
    Given I use the "<%= cb.proj3 %>" project
    When I execute on the "<%= cb.proj3p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj2s1 %>:27017 |
    Then the step should succeed
    And the output should contain "Hello"
    When I execute on the "<%= cb.proj3p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1p2 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"

  # @author bmeng@redhat.com
  # @case_id OCP-9646
  @admin
  Scenario: Isolate the network for the project which already make network global
    Given the env is using multitenant network
    Given I have a project
    And evaluation of `project.name` is stored in the :proj1 clipboard
    Given I create a new project
    And evaluation of `project.name` is stored in the :proj2 clipboard
    When I run the :oadm_pod_network_make_projects_global admin command with:
      | project | <%= cb.proj2 %> |
    Then the step should succeed

    Given I use the "<%= cb.proj1 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.name` is stored in the :proj1p1name clipboard
    And evaluation of `service("test-service-1").ip(user: user)` is stored in the :proj1s1 clipboard

    Given I use the "<%= cb.proj2 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][1]["metadata"]["name"] | test-service-2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=test-pods |
    And evaluation of `pod.ip` is stored in the :proj2p1 clipboard
    And evaluation of `pod.name` is stored in the :proj2p1name clipboard

    When I execute on the "<%= cb.proj2p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1s1 %>:27017 |
    Then the step should succeed
    And the output should contain "Hello"

    When I run the :oadm_pod_network_isolate_projects admin command with:
      | project | <%= cb.proj2 %> |
    Then the step should succeed
    When I run the :get admin command with:
      | resource | netnamespace |
      | resource_name | <%= cb.proj2 %> |
      | template | {{.netid}} |
    Then the step should succeed
    And the expression should be true> @result[:response] != 0

    Given I use the "<%= cb.proj1 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-1 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.ip` is stored in the :proj1p2 clipboard

    Given I use the "<%= cb.proj2 %>" project
    Given I obtain test data file "networking/list_for_pods.json"
    When I run oc create over "list_for_pods.json" replacing paths:
      | ["items"][0]["spec"]["replicas"] | 1 |
      | ["items"][0]["metadata"]["name"] | new-test-rc |
      | ["items"][0]["spec"]["template"]["metadata"]["labels"]["name"] | new-test-pods |
      | ["items"][1]["spec"]["selector"]["name"] | new-test-pods |
      | ["items"][1]["metadata"]["name"] | new-test-service-2 |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=new-test-pods |
    And evaluation of `pod.name` is stored in the :proj2p2name clipboard
    And evaluation of `service("new-test-service-2").ip(user: user)` is stored in the :proj2s2 clipboard

    Given I use the "<%= cb.proj1 %>" project
    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj2p1 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.proj1p1name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj2s2 %>:27017 |
    Then the step should fail
    And the output should not contain "Hello"
    Given I use the "<%= cb.proj2 %>" project
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1s1 %>:27017 |
    Then the step should fail
    And the output should not contain "Hello"
    When I execute on the "<%= cb.proj2p2name %>" pod:
      | curl | --connect-timeout | 5 | <%= cb.proj1p2 %>:8080 |
    Then the step should fail
    And the output should not contain "Hello"

