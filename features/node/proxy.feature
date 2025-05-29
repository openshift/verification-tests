Feature: Node proxy configuration tests

  # @author jhou@redhat.com
  @admin
  @flaky
  @proxy
  @4.20 @4.19 @4.18 @4.17 @4.16 @4.15 @4.14 @4.13 @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  Scenario Outline: Proxy config should be applied to kubelet and crio
    Given I use the "default" project
    Given I switch to cluster admin pseudo user
    When I run the :get client command with:
      | resource      | proxy   |
      | resource_name | cluster |
      | o             | yaml    |
    Then the step should succeed
    And evaluation of `YAML.load @result[:response]` is stored in the :proxy clipboard

    Given I store the ready and schedulable workers in the :workers clipboard
    When I run the :debug client command with:
      | resource     | node/<%= cb.workers.first.name %> |
      | oc_opts_end  |                                   |
      | exec_command | cat                               |
      | exec_command | /host/<file>                      |
    Then the step should succeed
    And the output should match:
      | Environment=HTTP_PROXY=<%= cb.proxy["spec"]["httpProxy"] %>  |
      | Environment=HTTPS_PROXY=<%= cb.proxy["spec"]["httpProxy"] %> |
      | Environment=NO_PROXY=.*<%= cb.proxy["spec"]["noProxy"] %>    |

    @vsphere-ipi @openstack-ipi @nutanix-ipi @ibmcloud-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi @alicloud-ipi
    @vsphere-upi @openstack-upi @nutanix-upi @ibmcloud-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi @alicloud-upi
    @network-ovnkubernetes @network-openshiftsdn
    @s390x @ppc64le @heterogeneous @arm64 @amd64
    @hypershift-hosted
    Examples:
      | case_id        | file                                                      |
      | OCP-24429:Node | /etc/systemd/system/kubelet.service.d/10-default-env.conf | # @case_id OCP-24429
      | OCP-24428:Node | /etc/systemd/system/crio.service.d/10-default-env.conf    | # @case_id OCP-24428


