Feature: apiserver and auth related upgrade check

  # @author pmali@redhat.com
  @upgrade-prepare
  @inactive
  @admin
  Scenario: Check Authentication operators and operands are upgraded correctly - prepare
    # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
    # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
    # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author pmali@redhat.com
  # @case_id OCP-22734
  @upgrade-check
  @inactive
  @admin
  Scenario: Check Authentication operators and operands are upgraded correctly
    Given the "authentication" operator version matches the current cluster version

    # Check cluster operators should be in correct status
    Given the expression should be true> cluster_operator('authentication').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('authentication').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('authentication').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('authentication').condition(type: 'Upgradeable')['status'] == "True"

    # operator pod image
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-authentication-operator             |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :auth_operator_image clipboard

    # Check cluster version
    When I run the :get admin command with:
      | resource | clusterversion/version           |
      | o        | jsonpath={.status.desired.image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :payload_image clipboard

    # Check the payload info
    Given evaluation of `"oc adm release info --registry-config=/var/lib/kubelet/config.json <%= cb.payload_image %>"` is stored in the :oc_adm_release_info clipboard
    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node

    # due to sensitive, didn't choose to dump and save the config.json file
    # for using the step `I run the :oadm_release_info admin command ...`

    And I run commands on the host:
      | <%= cb.oc_adm_release_info %> --image-for=cluster-authentication-operator |
    Then the step should succeed
    And the output should contain:
      | <%= cb.auth_operator_image %> |

  # @author xxia@redhat.com
  @upgrade-prepare
  @inactive
  @admin
  Scenario: Check apiserver operators and operands are upgraded correctly - prepare
    # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
    # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
    # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author xxia@redhat.com
  # @case_id OCP-22673
  @upgrade-check
  @admin
  @inactive
  Scenario: Check apiserver operators and operands are upgraded correctly
    Given the "kube-apiserver" operator version matches the current cluster version
    And the "openshift-apiserver" operator version matches the current cluster version
    # Check cluster operators should be in correct status
    Given the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('kube-apiserver').condition(type: 'Upgradeable')['status'] == "True"
    Given the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Progressing')['status'] == "False"
    And the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Available')['status'] == "True"
    And the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Degraded')['status'] == "False"
    And the expression should be true> cluster_operator('openshift-apiserver').condition(type: 'Upgradeable')['status'] == "True"
    # operators
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-kube-apiserver-operator             |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :kas_operator_image clipboard
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-apiserver-operator                  |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :oas_operator_image clipboard
    # operands
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-kube-apiserver                      |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :kas_image clipboard
    When I run the :get admin command with:
      | resource | po                                            |
      | n        | openshift-apiserver                           |
      | o        | jsonpath={.items[0].spec.containers[0].image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :oas_image clipboard

    When I run the :get admin command with:
      | resource | clusterversion/version           |
      | o        | jsonpath={.status.desired.image} |
    Then the step should succeed
    And evaluation of `@result[:response]` is stored in the :payload_image clipboard
    Given evaluation of `"oc adm release info --registry-config=/var/lib/kubelet/config.json <%= cb.payload_image %>"` is stored in the :oc_adm_release_info clipboard
    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node
    # due to sensitive, didn't choose to dump and save the config.json file
    # for using the step `I run the :oadm_release_info admin command ...`
    And I run commands on the host:
      | <%= cb.oc_adm_release_info %> --image-for=cluster-kube-apiserver-operator      |
      | <%= cb.oc_adm_release_info %> --image-for=cluster-openshift-apiserver-operator |
      | <%= cb.oc_adm_release_info %> --image-for=hyperkube                            |
      | <%= cb.oc_adm_release_info %> --image-for=openshift-apiserver                  |
    Then the step should succeed
    And the output should contain:
      | <%= cb.kas_operator_image %> |
      | <%= cb.oas_operator_image %> |
      | <%= cb.kas_image %>          |
      | <%= cb.oas_image %>          |

  # @author kewang@redhat.com
  @upgrade-prepare
  @admin
  @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @disconnected @connected
  @inactive
  Scenario: Default RBAC role, rolebinding, clusterrole and clusterrolebinding without any missing after upgraded - prepare
    When I run the :get admin command with:
      | resource | clusterroles.rbac                         |
      | o        | jsonpath={.items[*].metadata.annotations} |
    Then the output should contain:
      | autoupdate":"true" |
    And the output should not contain:
      | autoupdate":"false" |
    # Make some changes on clusterrole resources before upgrade
    Given as admin I successfully patch resource "clusterrole.rbac/system:build-strategy-custom" with:
      | {"rules": [{"apiGroups": ["","build.openshift.io"],"resources": ["builds/custom"],"verbs": [ "get" ]}] } |
    When I run the :get admin command with:
      | resource      | clusterroles.rbac            |
      | resource_name | system:build-strategy-custom |
      | o             | yaml                         |
    Then the expression should be true> !@result[:parsed]['rules'][0]['verbs'].include? "create"
    And the expression should be true> @result[:parsed]['rules'][0]['verbs'][0] == "get"
    Given as admin I successfully patch resource "clusterrolebinding.rbac/system:oauth-token-deleters" with:
      | {"subjects":[{"apiGroup": "rbac.authorization.k8s.io","kind": "Group","name": "system:authenticated"}]} |
    When I run the :get admin command with:
      | resource      | clusterrolebinding.rbac     |
      | resource_name | system:oauth-token-deleters |
      | o             | yaml                        |
    Then the expression should be true> @result[:parsed]['subjects'][0]['name'] == "system:authenticated"
    And the expression should be true> @result[:parsed]['subjects'][1] == nil

  # @author kewang@redhat.com
  # @case_id OCP-19470
  @upgrade-check
  @admin
  @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @disconnected @connected
  @inactive
  Scenario: Default RBAC role, rolebinding, clusterrole and clusterrolebinding without any missing after upgraded
    # Checking original clusterrole resources recovered after upgraded
    When I run the :get admin command with:
      | resource      | clusterroles.rbac            |
      | resource_name | system:build-strategy-custom |
      | o             | yaml                         |
    Then the expression should be true> @result[:parsed]['rules'][0]['verbs'][0] == "get"
    And the expression should be true> @result[:parsed]['rules'][1]['verbs'][0] == "create"
    And the expression should be true> @result[:parsed]['rules'][2]['verbs'][0] == "create"
    When I run the :get admin command with:
      | resource      | clusterrolebinding.rbac     |
      | resource_name | system:oauth-token-deleters |
      | o             | yaml                        |
    Then the expression should be true> @result[:parsed]['subjects'][0]['name'] == "system:authenticated"
    And the expression should be true> @result[:parsed]['subjects'][1]['name'] == "system:unauthenticated"

  # @author scheng@redhat.com
  @upgrade-prepare
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: Check the default SCCs should not be stomped by CVO - prepare
    Given as admin I successfully merge patch resource "scc/anyuid" with:
      | {"users": ["system:serviceaccount:test-scc:test-scc"]} |
    Given as admin I successfully merge patch resource "scc/privileged" with:
      | {"users": ["system:admin","system:serviceaccount:openshift-infra:build-controller","system:serviceaccount:test-scc:test-scc"]} |
    When I run the :get admin command with:
      | resource      | scc               |
      | resource_name | anyuid            |
      | o             | jsonpath={.users} |
    And the output should match:
      | system:serviceaccount:test-scc:test-scc |
    When I run the :get admin command with:
      | resource      | scc               |
      | resource_name | privileged        |
      | o             | jsonpath={.users} |
    And the output should match:
      | system:serviceaccount:test-scc:test-scc |

  # @author scheng@redhat.com
  # @case_id OCP-29741
  @upgrade-check
  @admin
  @destructive
  @4.12 @4.11 @4.10 @4.9 @4.8 @4.7 @4.6
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: Check the default SCCs should not be stomped by CVO
    Given the "kube-apiserver" operator version matches the current cluster version
    And the "openshift-apiserver" operator version matches the current cluster version
    When I run the :get admin command with:
      | resource      | scc               |
      | resource_name | anyuid            |
      | o             | jsonpath={.users} |
    And the output should match:
      | system:serviceaccount:test-scc:test-scc |
    When I run the :get admin command with:
      | resource      | scc               |
      | resource_name | privileged        |
      | o             | jsonpath={.users} |
    And the output should match:
      | system:serviceaccount:test-scc:test-scc |

  # @author scheng@redhat.com
  @admin
  @upgrade-prepare
  @users=upuser1,upuser2
  @4.12 @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: Upgrade action will cause re-generation of certificates for headless services to include the wildcard subjects - prepare
    Given I switch to the first user
    When I run the :new_project client command with:
      | project_name | service-ca-upgrade |
    Then the step should succeed
    And I obtain test data file "services/headless-services.yaml"
    When I run the :create client command with:
      | f | headless-services.yaml |
    Then the step should succeed
    Given I use the "service-ca-upgrade" project
    And I wait for the "test-serving-cert" secret to appear up to 120 seconds
    And I run the :extract client command with:
      | resource | secret/test-serving-cert |
      | confirm  | true                     |
    Then the step should succeed
    And the output should contain "tls.crt"

    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node
    And I run commands on the host:
      | openssl x509 -noout -text -in <(echo '<%= File.read("tls.crt") %>') |
    Then the step should succeed
    And the output should contain:
      | DNS:foo.service-ca-upgrade.svc, DNS:foo.service-ca-upgrade.svc.cluster.local |

  # @author scheng@redhat.com
  # @case_id OCP-41198
  @admin
  @upgrade-check
  @users=upuser1,upuser2
  @4.12 @4.11 @4.10 @4.9 @4.8
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: Upgrade action will cause re-generation of certificates for headless services to include the wildcard subjects
    Given the master version >= "4.8"
    Given I switch to cluster admin pseudo user
    Given I use the "service-ca-upgrade" project
    When I run the :extract client command with:
      | resource | secret/test-serving-cert |
      | confirm  | true                     |
    Then the step should succeed
    And the output should contain "tls.crt"

    When I store the ready and schedulable masters in the clipboard
    And I use the "<%= cb.nodes[0].name %>" node
    And I run commands on the host:
      | openssl x509 -noout -text -in <(echo '<%= File.read("tls.crt") %>') |
    Then the step should succeed
    And the output should contain:
      | DNS:foo.service-ca-upgrade.svc, DNS:foo.service-ca-upgrade.svc.cluster.local     |
      | DNS:*.foo.service-ca-upgrade.svc, DNS:*.foo.service-ca-upgrade.svc.cluster.local |

  # @author xxia@redhat.com
  @upgrade-prepare
  @qeci
  @admin
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: kube-apiserver and openshift-apiserver should have zero-disruption upgrade - prepare
    # According to our upgrade workflow, we need an upgrade-prepare and upgrade-check for each scenario.
    # But some of them do not need any prepare steps, which lead to errors "can not find scenarios" in the log.
    # So we just add a simple/useless step here to get rid of the errors in the log.
    Given the expression should be true> "True" == "True"

  # @author xxia@redhat.com
  # @case_id OCP-34223
  @upgrade-check
  @qeci
  @admin
  @4.12 @4.11 @4.10 @4.9
  @vsphere-ipi @openstack-ipi @gcp-ipi @baremetal-ipi @azure-ipi @aws-ipi
  @vsphere-upi @openstack-upi @gcp-upi @baremetal-upi @azure-upi @aws-upi
  @singlenode
  @upgrade
  @network-ovnkubernetes @network-openshiftsdn
  @proxy @noproxy @disconnected @connected
  @heterogeneous @arm64 @amd64
  Scenario: kube-apiserver and openshift-apiserver should have zero-disruption upgrade
    # This case needs keep running oc commands against servers during upgrade, but our framework does not support
    # So using a workaround: run them in a background script during upgrade CI job and check result here
    # The project is created in the script
    When I run the :get admin command with:
      | resource | cm/log         |
      | o        | yaml           |
      | n        | ocp-34223-proj |
    Then the step should succeed
    # This is to discover bugs like: 1845411 1804717 1912820
    And the expression should be true> @result[:response].scan(/failed/).length <= 1
