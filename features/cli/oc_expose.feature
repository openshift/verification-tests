Feature: oc_expose.feature

  # @author pruan@redhat.com
  # @case_id OCP-10873
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @azure-ipi
  Scenario: Access app througth secure service and regenerate service serving certs if it about to expire
    Given the master version >= "3.3"
    Given I have a project
    Given a "caddyfile.conf" file is created with the following lines:
    """
    :8443 {
      tls /etc/serving-cert/tls.crt /etc/serving-cert/tls.key
      root /srv/publics
      browse /test
    }
    :8080 {
      root /srv/public
      browse /test
    }
    """
    When I run the :create_service client command with:
      | createservice_type  | clusterip |
      | name                | hello     |
      | tcp                 | 443:8443  |
    Then the step should succeed
    And I run the :annotate client command with:
      | resource     | svc                                                         |
      | resourcename | hello                                                       |
      | keyval       | service.alpha.openshift.io/serving-cert-secret-name=ssl-key |
    Then the step should succeed
    And I wait for the "ssl-key" secret to appear
    And evaluation of `Time.now` is stored in the :t1 clipboard
    And I run the :create_configmap client command with:
      | name      | default-conf   |
      | from_file | caddyfile.conf |
    Then the step should succeed
    Given I obtain test data file "deployment/OCP-10873/dc.yaml"
    When I run the :create client command with:
      | f | dc.yaml |
    Then the step should succeed
    And I wait until the status of deployment "hello" becomes :complete
    Given I have a pod-for-ping in the project
    When I execute on the "hello-pod" pod:
      | curl | --cacert | /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt | https://hello.<%= project.name %>.svc:443 |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift-1 https-8443 |

    # Below checkpoint is in later version
    Given the master version >= "3.5"
    When I run the :extract client command with:
      | resource | secret/ssl-key   |
    Then the step should succeed
    Given evaluation of `File.read("tls.crt")` is stored in the :crt clipboard
    And evaluation of `v = secret('ssl-key').created; (v.is_a? Time) ? v : Time.parse(v)` is stored in the :birth clipboard
    And evaluation of `Time.now` is stored in the :t2 clipboard
    And evaluation of `(cb.birth + (cb.t2 - cb.t1) + 3600 + 60).utc.strftime "%Y-%m-%dT%H:%M:%SZ"` is stored in the :newexpiry clipboard
    When I run the :annotate client command with:
      | resource     | secret/ssl-key                                          |
      | keyval       | service.alpha.openshift.io/expiry=<%= cb.newexpiry %>   |
      | keyval       | service.beta.openshift.io/expiry=<%= cb.newexpiry %>    |
      | overwrite    | true                                                    |
    Then the step should succeed
    Given 30 seconds have passed
    When I run the :extract client command with:
      | resource | secret/ssl-key   |
      | confirm  | true             |
    Then the step should succeed
    # When the expiry time has more than 3600s left, the cert will not regenerate
    And the expression should be true> File.read("tls.crt") == cb.crt
    # When the expiry time has less than 3600s, we could wait the cert to regenerate
    Given I wait up to 1800 seconds for the steps to pass:
    """
    Given 60 seconds have passed
    When I run the :extract client command with:
      | resource | secret/ssl-key   |
      | confirm  | true             |
    Then the step should succeed
    And the expression should be true> File.read("tls.crt") != cb.crt
    """
    When I execute on the "hello-pod" pod:
      | curl | --cacert | /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt | https://hello.<%= project.name %>.svc:443 |
    Then the step should succeed
    And the output should contain:
      | Hello-OpenShift-1 https-8443 |

