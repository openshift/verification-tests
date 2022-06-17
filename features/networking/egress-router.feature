Feature: Egress router related features

  # @author bmeng@redhat.com
  # @case_id OCP-14106
  @admin
  Scenario: OCP-14106 User can use egress router as both initContainer mode and legacy mode
    Given the cluster is running on OpenStack
    And the node's default gateway is stored in the clipboard
    And default router image is stored into the :router_image clipboard

    # Create egress router with legacy mode
    # IP 10.4.205.4 points to the redhat internal service bugzilla.redhat.com
    Given I have a project
    And SCC "privileged" is added to the "default" service account
    And I store a random unused IP address from the reserved range to the :valid_ip clipboard
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/egress-router/legacy-egress-router-list.json" replacing paths:
      | ["items"][0]["spec"]["template"]["spec"]["containers"][0]["image"] | <%= cb.router_image.gsub("haproxy","egress") %> |
      | ["items"][0]["spec"]["template"]["spec"]["containers"][0]["env"] | [{"name":"EGRESS_SOURCE","value":"<%= cb.valid_ip %>"},{"name":"EGRESS_GATEWAY","value":"<%= cb.gateway %>"},{"name":"EGRESS_DESTINATION","value":"10.4.205.4"},{"name":"EGRESS_ROUTER_MODE","value":"legacy"}] |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=egress-router |
    Then evaluation of `pod.ip` is stored in the :egress_router_ip clipboard

    Given I have a pod-for-ping in the project
    And I wait up to 60 seconds for the steps to pass:
    """
    When I execute on the pod:
      | curl | -IskSL | --connect-timeout | 5 | <%= cb.egress_router_ip %> |
    Then the step should succeed
    And the output should contain "Bugzilla"
    When I execute on the pod:
      | curl | -IskSL | --connect-timeout | 5 | https://<%= cb.egress_router_ip %>/ |
    Then the step should succeed
    And the output should contain "Bugzilla"
    """

  # @author bmeng@redhat.com
  # @case_id OCP-14686
  @admin
  Scenario: OCP-14686 Multiple destination values for http proxy
    Given the cluster is running on OpenStack
    And the node's default gateway is stored in the clipboard
    And default router image is stored into the :router_image clipboard

    # Create egress http proxy with multiple destinations
    Given I have a project
    And evaluation of `project.name` is stored in the :project clipboard
    And SCC "privileged" is added to the "default" service account
    And I store a random unused IP address from the reserved range to the :valid_ip clipboard
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/egress-router/egress-http-proxy.yaml" replacing paths:
      | ["spec"]["initContainers"][0]["image"] | <%= cb.router_image.gsub("haproxy","egress") %> |
      | ["spec"]["initContainers"][0]["env"][0]["value"] | <%= cb.valid_ip %> |
      | ["spec"]["initContainers"][0]["env"][1]["value"] | <%= cb.gateway %> |
      | ["spec"]["initContainers"][0]["env"][2]["value"] | http-proxy |
      | ["spec"]["containers"][0]["image"] | <%= cb.router_image.gsub("haproxy-router","egress-http-proxy") %> |
      | ["spec"]["containers"][0]["env"][0]["value"] | "!www.youdao.com\\n*.google.com\\n!10.4.205.4\\n*" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=egress-http-proxy |
    Then evaluation of `pod.ip` is stored in the :egress_http_proxy_ip clipboard

    # access the remote services with the egress http proxy
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl | -Isk | --proxy | <%= cb.egress_http_proxy_ip %>:8080 | --connect-timeout | 5 | https://bugzilla.redhat.com/ |
    Then the output should contain "403 Forbidden"
    When I execute on the pod:
      | curl | -Isk | --proxy | <%= cb.egress_http_proxy_ip %>:8080 | --connect-timeout | 5 | http://www.youdao.com/ |
    Then the output should contain "403 Forbidden"
    When I execute on the pod:
      | curl | -Isk | --proxy | <%= cb.egress_http_proxy_ip %>:8080 | --connect-timeout | 5 | https://www.google.com/ |
    Then the step should succeed
    Then the output should contain "200"
    When I execute on the pod:
      | curl | -Isk | --proxy | <%= cb.egress_http_proxy_ip %>:8080 | --connect-timeout | 5 | https://www.amazon.com/ |
    Then the step should succeed
    And the output should contain "200"

  # @author bmeng@redhat.com
  # @case_id OCP-15056
  @admin
  Scenario: OCP-15056 Egress router works with multiple DNS names destination
    Given the cluster is running on OpenStack
    And the node's default gateway is stored in the clipboard
    And default router image is stored into the :router_image clipboard

    # Create the egress dns proxy with multiple dns names as destination
    Given I have a project
    And evaluation of `project.name` is stored in the :project clipboard
    And SCC "privileged" is added to the "default" service account
    And I store a random unused IP address from the reserved range to the :valid_ip clipboard
    # IP 5.196.70.86 points to the external web service portquiz.net which is serving on all TCP ports
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/egress-router/egress-dns-proxy.yaml" replacing paths:
      | ["spec"]["initContainers"][0]["image"] | <%= cb.router_image.gsub("haproxy","egress") %> |
      | ["spec"]["initContainers"][0]["env"][0]["value"] | <%= cb.valid_ip %> |
      | ["spec"]["initContainers"][0]["env"][1]["value"] | <%= cb.gateway %> |
      | ["spec"]["initContainers"][0]["env"][2]["value"] | dns-proxy |
      | ["spec"]["containers"][0]["image"] | <%= cb.router_image.gsub("haproxy-router","egress-dns-proxy") %> |
      | ["spec"]["containers"][0]["env"][1]["value"] | "80 www.youdao.com\\n8000 5.196.70.86 80\\n8443 bugzilla.redhat.com 443" |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=egress-dns-pod |
    Then evaluation of `pod.ip` is stored in the :egress_dns_proxy_ip clipboard

    # Create service for the egress dns proxy pod
    When I run the :expose client command with:
      | resource       | pod           |
      | resource_name  | egress-dns-pod|
      | port           | 80,8000,8443  |
      | protocol       | TCP           |
    Then the step should succeed

    # Create pod and access the external services via egress dns proxy service name
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl | -IsS | --connect-timeout | 5 | http://egress-dns-pod.<%= cb.project %>.svc:80 |
    Then the step should succeed
    And the output should contain "youdao.com"
    When I execute on the pod:
      | curl | -sS | --connect-timeout | 5 | -H | host: portquiz.net:8000 | http://egress-dns-pod.<%= cb.project %>.svc:8000 |
    Then the step should succeed
    And the output should contain "test successful"
    When I execute on the pod:
      | curl | -IskS | --connect-timeout | 5 | https://egress-dns-pod.<%= cb.project %>.svc:8443 |
    Then the step should succeed
    And the output should contain "bugzilla"
    When I execute on the pod:
      | curl | -IskS | --connect-timeout | 5 | https://egress-dns-pod.<%= cb.project %>.svc:8888 |
    Then the step should fail
    And the output should not contain "bugzilla"
    And the output should not contain "youdao"

  # @author bmeng@redhat.com
  # @case_id OCP-15057
  @admin
  Scenario: OCP-15057 Egress router works with DNS names destination configured in ConfigMap
    Given the cluster is running on OpenStack
    And the node's default gateway is stored in the clipboard
    And default router image is stored into the :router_image clipboard

    # Create configmap for egress dns proxy
    # IP 5.196.70.86 points to the external web services portquiz.net which serves on all the TCP ports
    Given I have a project
    And SCC "privileged" is added to the "default" service account
    And a "egress-dns.txt" file is created with the following lines:
    """
    # redirect from local 80 port to remote www.youdao.com 80 port
	80 www.youdao.com
    # redirect from local 8000 port to remote 5.196.70.86(portquiz.net) 80 port
	8000 5.196.70.86 80
    # redirect from local 8443 port to remote bugzilla.redhat.com 443 port
	8443 bugzilla.redhat.com 443
    """
    When I run the :create_configmap client command with:
      | name      | egress-dns |
      | from_file | destination=egress-dns.txt |
    Then the step should succeed

    # Create egress dns proxy with the configmap above
    Given I store a random unused IP address from the reserved range to the :valid_ip clipboard
    When I run oc create over "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/networking/egress-ingress/egress-router/egress-dns-proxy.yaml" replacing paths:
      | ["spec"]["initContainers"][0]["image"] | <%= cb.router_image.gsub("haproxy","egress") %> |
      | ["spec"]["initContainers"][0]["env"][0]["value"] | <%= cb.valid_ip %> |
      | ["spec"]["initContainers"][0]["env"][1]["value"] | <%= cb.gateway %> |
      | ["spec"]["initContainers"][0]["env"][2]["value"] | dns-proxy |
      | ["spec"]["containers"][0]["image"] | <%= cb.router_image.gsub("haproxy-router","egress-dns-proxy") %> |
      | ["spec"]["containers"][0]["env"][1] | {"name":"EGRESS_DNS_PROXY_DESTINATION","valueFrom":{"configMapKeyRef":{"name":"egress-dns","key":"destination"}}}|
    And a pod becomes ready with labels:
      | name=egress-dns-pod |
    Then evaluation of `pod.ip` is stored in the :egress_router_ip clipboard

    # create pod and try to access the remote services via egress dns proxy
    Given I have a pod-for-ping in the project
    When I execute on the pod:
      | curl | -IsS | --connect-timeout | 5 | http://<%= cb.egress_router_ip %>:80 |
    Then the step should succeed
    And the output should contain "youdao.com"
    When I execute on the pod:
      | curl | -sS | --connect-timeout | 5 | -H | host: portquiz.net:8000 | http://<%= cb.egress_router_ip %>:8000 |
    Then the step should succeed
    And the output should contain "test successful"
    When I execute on the pod:
      | curl | -IskS | --connect-timeout | 5 | https://<%= cb.egress_router_ip %>:8443 |
    Then the step should succeed
    And the output should contain "bugzilla"
    When I execute on the pod:
      | curl | -IskS | --connect-timeout | 5 | https://<%= cb.egress_router_ip %>:8888 |
    Then the step should fail
    And the output should not contain "bugzilla"
    And the output should not contain "youdao"

