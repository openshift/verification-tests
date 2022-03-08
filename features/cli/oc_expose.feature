Feature: oc_expose.feature

  # @author pruan@redhat.com
  # @case_id OCP-10873
  Scenario: Access app througth secure service and regenerate service serving certs if it about to expire
    Given the master version >= "3.3"
    Given I have a project
    Given I obtain test data file "deployment/OCP-10873/svc.json"
    When I run the :create client command with:
      | f | svc.json |
    And the step should succeed
    And I wait for the "ssl-key" secret to appear up to 30 seconds
    And evaluation of `Time.now` is stored in the :t1 clipboard
    Given I obtain test data file "deployment/OCP-10873/dc.yaml"
    When I run the :create client command with:
      | f | dc.yaml |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=web-server-rc |
    And evaluation of `pod.name` is stored in the :websrv_pod clipboard
    When I get project configmaps
    Then the output should match "nginx-config"
    Given I have a pod-for-ping in the project
    When I execute on the "hello-pod" pod:
      | curl | --cacert | /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt | https://hello.<%= project.name %>.svc:443 |
    Then the step should succeed
    And the output should match:
      | Hello-OpenShift web-server-rc.*https-8443 default |

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
    And the output should match:
      | Hello-OpenShift web-server-rc.*https-8443 default |
