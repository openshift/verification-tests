Feature: Downward API

  # @author qwang@redhat.com
  # @case_id OCP-10707
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Pods can get IPs via downward API under race condition
    Given I have a project
    Given I obtain test data file "downwardapi/ocp10707/pod-downwardapi-env.yaml"
    When I run the :create client command with:
      | filename  | pod-downwardapi-env.yaml |
    Then the step should succeed
    Given the pod named "downwardapi-env" becomes ready
    When I execute on the pod:
      | env |
    Then the output should contain "MYSQL_POD_IP=1"

  # @author cryan@redhat.com
  # @case_id OCP-10628
  @smoke
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: downward api pod name and pod namespace as env variables
    Given I have a project
    Given I obtain test data file "downwardapi/ocp10628/downward-example.yaml"
    When I run the :create client command with:
      | f | downward-example.yaml |
    Then the step should succeed
    And the pod named "dapi-test-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-test-pod |
    Then the step should succeed
    And the output should contain:
      | POD_NAME=dapi-test-pod |
      | POD_NAMESPACE=<%= project.name %> |

  # @author qwang@redhat.com
  # @case_id OCP-10708
  @smoke
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Container consume infomation from the downward API using a volume plugin
    Given I have a project
    Given I obtain test data file "downwardapi/pod-dapi-volume.yaml"
    When I run the :create client command with:
      | f | pod-dapi-volume.yaml |
    Then the step should succeed
    Given the pod named "pod-dapi-volume" becomes ready
    When I execute on the pod:
      | ls | -laR | /var/tmp/podinfo |
    Then the output should match:
      | annotations -> \.\.[a-z]+/annotations |
      | labels -> \.\.[a-z]+/labels           |
      | name -> \.\.[a-z]+/name               |
      | namespace -> \.\.[a-z]+/namespace     |
    When I execute on the pod:
      | cat | /var/tmp/podinfo/name |
    Then the output should contain:
      | pod-dapi-volume |
    And I execute on the pod:
      | cat | /var/tmp/podinfo/namespace |
    Then the output should contain:
      | <%= project.name %> |
    And I execute on the pod:
      | cat | /var/tmp/podinfo/labels |
    Then the output should contain:
      | rack="a111" |
      | region="r1" |
      | zone="z11"  |
    And I execute on the pod:
      | cat | /var/tmp/podinfo/annotations |
    Then the output should contain:
      | build="one"      |
      | builder="qe-one" |
    # Change the value of annotations
    When I run the :patch client command with:
      | resource      | pod |
      | resource_name | pod-dapi-volume |
      | p             | {"metadata":{"annotations":{"build":"two"}}} |
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /var/tmp/podinfo/annotations |
    Then the output should contain:
      | build="two" |
    """
    Then the step should succeed
    # Delete one of labels
    When I run the :patch client command with:
      | resource      | pod                                   |
      | resource_name | pod-dapi-volume                       |
      | p             | {"metadata":{"labels":{"rack":null}}} |
    And I wait up to 120 seconds for the steps to pass:
    """
    When I execute on the pod:
      | cat | /var/tmp/podinfo/labels |
    Then the output should not contain:
      | rack="a111" |
    And the output should contain:
      | region="r1" |
      | zone="z11"  |
    """
    Then the step should succeed

  # @author qwang@redhat.com
  # @case_id OCP-11977
  @admin
  @inactive
  Scenario: Using resources downward API via volume plugin should be compatible with metadata downward API
    Given I have a project
    Given I obtain test data file "downwardapi/dapi-resources-metadata-volume-pod.yaml"
    When I run the :create client command with:
      | f | dapi-resources-metadata-volume-pod.yaml |
    Then the step should succeed
    Given the pod named "dapi-resources-metadata-volume-pod" becomes ready
    When I execute on the pod:
      | cat | /etc/info/cpu_limit |
    Then the step should succeed
    And the output should match "^500$"
    When I execute on the pod:
      | cat | /etc/info/cpu_request |
    Then the step should succeed
    And the output should match "^1$"
    When I execute on the pod:
      | cat | /etc/info/memory_request |
    Then the step should succeed
    And the output should match "^64$"
    When I execute on the pod:
      | cat | /etc/info/memory_limit |
    Then the step should succeed
    And the output should match "^134217728$"
    When I execute on the pod:
      | cat | /etc/info/name |
    Then the step should succeed
    And the output should contain "dapi-resources-metadata-volume-pod"
    When I execute on the pod:
      | cat | /etc/info/namespace |
    Then the step should succeed
    And the output should contain "<%= project.name %>"
    When I execute on the pod:
      | cat | /etc/info/labels |
    Then the step should succeed
    And the output should contain "name="dapi-resources-metadata-volume-pod""
    When I execute on the pod:
      | cat | /etc/info/annotations |
    Then the step should succeed
    And the output should contain:
      | kubernetes.io/config.source="api" |
      | kubernetes.io/config.seen=        |
    # Test file without requests, use limits as requests by default
    Given I ensure "dapi-resources-metadata-volume-pod" pod is deleted
    Given I obtain test data file "downwardapi/dapi-resources-metadata-volume-pod-without-requests.yaml"
    When I run the :create client command with:
      | f | dapi-resources-metadata-volume-pod-without-requests.yaml |
    Then the step should succeed
    Given the pod named "dapi-resources-metadata-volume-pod-without-requests" becomes ready
    When I execute on the pod:
      | cat | /etc/info/cpu_limit | /etc/info/cpu_request | /etc/info/memory_request | /etc/info/memory_limit |
    Then the step should succeed
    And the output should contain "5001128134217728"
    # Test file without limits, use node allocatable as limits by default
    Given I ensure "dapi-resources-metadata-volume-pod-without-requests" pod is deleted
    Given I obtain test data file "downwardapi/dapi-resources-metadata-volume-pod-without-limits.yaml"
    When I run the :create client command with:
      | f | dapi-resources-metadata-volume-pod-without-limits.yaml |
    Then the step should succeed
    Given the pod named "dapi-resources-metadata-volume-pod-without-limits" becomes ready
    When I execute on the pod:
      | cat | /etc/info/cpu_request | /etc/info/memory_request |
    Then the step should succeed
    And the output by order should match:
      | 250 |
      | 64  |
    Given evaluation of `pod("dapi-resources-metadata-volume-pod-without-limits").node_name(user: user)` is stored in the :node clipboard
    When I run the :get admin command with:
      | resource      | node           |
      | resource_name | <%= cb.node %> |
      | o             | yaml           |
    Then the step should succeed
    And evaluation of `@result[:parsed]["status"]["allocatable"]["cpu"]` is stored in the :nodecpulimit clipboard
    And evaluation of `@result[:parsed]["status"]["allocatable"]["memory"].gsub(/Ki/,'')` is stored in the :nodememorylimit clipboard
    When I execute on the pod:
      | cat | /etc/info/cpu_limit |
    Then the step should succeed
    And the output should equal "<%= cb.nodecpulimit %>"
    When I execute on the pod:
      | cat | /etc/info/memory_limit |
    Then the step should succeed
    And the output should equal "<%= cb.nodememorylimit %>"

  # @author qwang@redhat.com
  # @case_id OCP-11618
  @admin
  @inactive
  Scenario: Could expose resouces limits and requests via volume plugin from Downward APIs with magics keys
    Given I have a project
    Given I obtain test data file "downwardapi/dapi-resources-volume-magic-keys-pod.yaml"
    When I run the :create client command with:
      | f | dapi-resources-volume-magic-keys-pod.yaml |
    Then the step should succeed
    Given the pod named "dapi-resources-volume-magic-keys-pod" becomes ready
    When I execute on the pod:
      | cat | /etc/resources/cpu_limit | /etc/resources/cpu_request | /etc/resources/memory_request | /etc/resources/memory_limit |
    Then the step should succeed
    And the output should contain "500164134217728"
    # Test file without requests, use limits as requests by default
    Given I ensure "dapi-resources-volume-magic-keys-pod" pod is deleted
    Given I obtain test data file "downwardapi/dapi-resources-volume-magic-keys-pod-without-requests.yaml"
    When I run the :create client command with:
      | f | dapi-resources-volume-magic-keys-pod-without-requests.yaml |
    Then the step should succeed
    Given the pod named "dapi-resources-volume-magic-keys-pod-without-requests" becomes ready
    When I execute on the pod:
      | cat | /etc/resources/cpu_limit | /etc/resources/cpu_request | /etc/resources/memory_request | /etc/resources/memory_limit |
    Then the step should succeed
    And the output should contain "5001128134217728"
    # Test file without limits, use node allocatable as limits by default
    Given I ensure "dapi-resources-volume-magic-keys-pod-without-requests" pod is deleted
    Given I obtain test data file "downwardapi/dapi-resources-volume-magic-keys-pod-without-limits.yaml"
    When I run the :create client command with:
      | f | dapi-resources-volume-magic-keys-pod-without-limits.yaml |
    Then the step should succeed
    Given the pod named "dapi-resources-volume-magic-keys-pod-without-limits" becomes ready
    When I execute on the pod:
      | cat | /etc/resources/cpu_request | /etc/resources/memory_request |
    Then the step should succeed
    And the output by order should match:
      | 250 |
      | 64  |
    Given evaluation of `pod("dapi-resources-volume-magic-keys-pod-without-limits").node_name(user: user)` is stored in the :node clipboard
    When I run the :get admin command with:
      | resource      | node           |
      | resource_name | <%= cb.node %> |
      | o             | yaml           |
    Then the step should succeed
    And evaluation of `@result[:parsed]["status"]["allocatable"]["cpu"]` is stored in the :nodecpulimit clipboard
    And evaluation of `@result[:parsed]["status"]["allocatable"]["memory"].gsub(/Ki/,'')` is stored in the :nodememorylimit clipboard
    When I execute on the pod:
      | cat | /etc/resources/cpu_limit |
    Then the output should equal "<%= cb.nodecpulimit %>"
    When I execute on the pod:
      | cat | /etc/resources/memory_limit |
    Then the output should equal "<%= cb.nodememorylimit %>"

  # @author qwang@redhat.com
  # @case_id OCP-11816
  @admin
  @inactive
  Scenario: Using resources downward API via ENV should be compatible with metadata downward API
    Given I have a project
    Given I obtain test data file "downwardapi/dapi-resources-metadata-env-pod.yaml"
    When I run the :create client command with:
      | f | dapi-resources-metadata-env-pod.yaml |
    Then the step should succeed
    And the pod named "dapi-resources-metadata-env-pod" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-resources-metadata-env-pod |
    Then the step should succeed
    And the output should contain:
      | MY_MEM_LIMIT=67108864 |
      | MY_CPU_LIMIT=1        |
      | MY_MEM_REQUEST=32     |
      | MY_CPU_REQUEST=1      |
    # Test file without requests, use limits as requests by default
    Given I ensure "dapi-resources-metadata-env-pod" pod is deleted
    Given I obtain test data file "downwardapi/dapi-resources-metadata-env-pod-without-requests.yaml"
    When I run the :create client command with:
      | f | dapi-resources-metadata-env-pod-without-requests.yaml |
    Then the step should succeed
    And the pod named "dapi-resources-metadata-env-pod-without-requests" status becomes :succeeded
    When I run the :logs client command with:
      | resource_name | dapi-resources-metadata-env-pod-without-requests |
    Then the step should succeed
    And the output should contain:
      | MY_MEM_LIMIT=67108864 |
      | MY_CPU_LIMIT=1        |
      | MY_MEM_REQUEST=64     |
      | MY_CPU_REQUEST=1      |
    # Test file without limits, use node allocatable as limits by default
    Given I ensure "dapi-resources-metadata-env-pod-without-requests" pod is deleted
    Given I obtain test data file "downwardapi/dapi-resources-metadata-env-pod-without-limits.yaml"
    When I run the :create client command with:
      | f | dapi-resources-metadata-env-pod-without-limits.yaml |
    Then the step should succeed
    And the pod named "dapi-resources-metadata-env-pod-without-limits" status becomes :succeeded
    Given evaluation of `pod("dapi-resources-metadata-env-pod-without-limits").node_name(user: user)` is stored in the :node clipboard
    When I run the :get admin command with:
      | resource      | node           |
      | resource_name | <%= cb.node %> |
      | o             | yaml           |
    Then the step should succeed
    And evaluation of `@result[:parsed]["status"]["allocatable"]["cpu"]` is stored in the :nodecpulimit clipboard
    And evaluation of `@result[:parsed]["status"]["allocatable"]["memory"].gsub(/Ki/,'')` is stored in the :nodememorylimit clipboard
    When I run the :logs client command with:
      | resource_name | dapi-resources-metadata-env-pod-without-limits |
    Then the step should succeed
    And the output should contain:
      | MY_MEM_REQUEST=32                                |
      | MY_CPU_REQUEST=1                                 |
      | MY_MEM_LIMIT=<%= cb.nodememorylimit.to_i*1024 %> |
      | MY_CPU_LIMIT=<%= cb.nodecpulimit %>              |
    When I run the :describe client command with:
      | resource | pod                                              |
      | name     | dapi-resources-metadata-env-pod-without-limits |
    Then the step should succeed
    And the output should match:
      | MY_CPU_REQUEST:\\s+1 \(requests.cpu\)               |
      | MY_CPU_LIMIT:\\s+node allocatable \(limits.cpu\)    |
      | MY_MEM_REQUEST:\\s+32 \(requests.memory\)           |
      | MY_MEM_LIMIT:\\s+node allocatable \(limits.memory\) |

