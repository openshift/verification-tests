Feature: All in one volume

  # @author chezhang@redhat.com
  # @case_id OCP-11683
  Scenario: OCP-11683 Project secrets, configmap and downward API into the same volume with normal keys and path
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/allinone-volume/configmap.yaml |
    Then the step should succeed
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/allinone-volume/secret.yaml |
    Then the step should succeed

    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/allinone-volume/allinone-normal-pod.yaml |
    Then the step should succeed
    Given the pod named "allinone-normal" becomes ready
    When I execute on the pod:
      | sh |
      | -c |
      | stat -c %a /all-in-one; stat -c %a /all-in-one/..data/mysecret; cat /all-in-one/mysecret/my-username; stat -c %a /all-in-one/..data/mysecret/my-username; cat /all-in-one/mysecret/my-passwd; stat -c %a /all-in-one/..data/mysecret/my-passwd; stat -c %a /all-in-one/..data/mydapi; cat /all-in-one/mydapi/labels; echo; stat -c %a /all-in-one/..data/mydapi/labels; cat /all-in-one/mydapi/name; echo; stat -c %a /all-in-one/..data/mydapi/name; cat /all-in-one/mydapi/cpu_limit; echo; stat -c %a /all-in-one/..data/mydapi/cpu_limit; stat -c %a /all-in-one/..data/myconfigmap; cat /all-in-one/myconfigmap/shared-config; echo; stat -c %a /all-in-one/..data/myconfigmap/shared-config; cat /all-in-one/myconfigmap/private-config; echo; stat -c %a /all-in-one/..data/myconfigmap/private-config |
    Then the output by order should match:
      | ^3777$          |
      | ^2755$          |
      | value-1         |
      | ^644$           |
      | value-2         |
      | ^644$           |
      | ^2755$          |
      | region="one"    |
      | ^644$           |
      | allinone-normal |
      | ^644$           |
      | ^500$           |
      | ^644$           |
      | ^2755$          |
      | very            |
      | ^644$           |
      | charm           |
      | ^644$           |

