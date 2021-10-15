Feature: Node proxy configuration tests

  # @author jhou@redhat.com
  @admin
  @flaky
  @aws-ipi
  @proxy
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  @baremetal-ipi
  @openstack-ipi
  @openstack-upi
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

    Examples:
      | file                                                      |
      | /etc/systemd/system/kubelet.service.d/10-default-env.conf | # @case_id OCP-24429
      | /etc/systemd/system/crio.service.d/10-default-env.conf    | # @case_id OCP-24428


