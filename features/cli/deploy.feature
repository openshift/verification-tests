Feature: deployment related features

  # @author xxing@redhat.com
  # @case_id OCP-12543
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Restart a failed deployment by oc deploy
    Given I have a project
    Given I obtain test data file "deployment/dc-with-pre-mid-post.yaml"
    When I run the :create client command with:
      | f | dc-with-pre-mid-post.yaml |
    Then the step should succeed
    # Wait and make the cancel succeed stably
    And I wait until the status of deployment "hooks" becomes :running
    When  I run the :rollout_cancel client command with:
      | resource | deploymentConfig   |
      | name     | hooks              |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :failed
    When I run the :rollout_status client command with:
      | resource | deploymentConfig |
      | name     | hooks            |
    Then the output should match "was cancelled"
    When I run the :rollout_retry client command with:
      | resource | deploymentConfig   |
      | name     | hooks              |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :rollout_status client command with:
      | resource | deploymentConfig |
      | name     | hooks            |
    Then the output should match "successfully rolled out"

  # @author xxing@redhat.com
  # @case_id OCP-10643
  @smoke
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Manually make deployment
    Given I have a project
    Given I obtain test data file "deployment/manual.json"
    When I run the :create client command with:
      | f | manual.json |
    Then the step should succeed
    When I run the :rollout_status client command with:
      | resource | deploymentConfig |
      | name     | hooks            |
    Then the output should match "waiting on manual update"
    And I check that the "hooks" deployment_config exists in the project
    When I run the :rollout_latest client command with:
      | resource | hooks |
    Then the output should contain "rolled out"
    # Wait the deployment till complete
    And the pod named "hooks-1-deploy" becomes ready
    Given I wait for the pod named "hooks-1-deploy" to die
    When I run the :rollout_status client command with:
      | resource | deploymentConfig |
      | name     | hooks            |
    Then the output should match "successfully rolled out"
    And I check that the "hooks" deployment_config exists in the project
    # Make the edit action
    When I get project dc named "hooks" as JSON
    And I save the output to file> hooks.json
    And I replace lines in "hooks.json":
      | Recreate | Rolling |
    When I run the :replace client command with:
      | f | hooks.json |
    When I run the :rollout_latest client command with:
      | resource | hooks |
    Then the output should contain "rolled out"
    When I get project dc named "hooks" as YAML
    Then the output should contain:
      | type: Rolling |

  # @author xxing@redhat.com
  # @case_id OCP-11695
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: CLI rollback output to file
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    Given I obtain test data file "deployment/updatev1.json"
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :replace client command with:
      | f | updatev1.json |
    Then the step should succeed
    """
    When I get project dc named "hooks"
    Then the output should match:
      | hooks.*|
    And I wait up to 60 seconds for the steps to pass:
    """
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "latestVersion": 2 |
    """
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
      | output                  | json    |
    #Show the container config only
    Then the output should match:
      | "[vV]alue": "Plqe5Wev" |
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
      | output                  | yaml    |
      | change_strategy         |         |
      | change_triggers         |         |
      | change_scaling_settings |         |
    Then the output should match:
      | [rR]eplicas:\\s+1        |
      | [tT]ype:\\s+Recreate     |
      | [vV]alue:\\s+Plqe5Wev    |
      | [tT]ype:\\s+ConfigChange |

  # @author xxing@redhat.com
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario Outline: CLI rollback two more components of deploymentconfig
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1          |
      | "value": "Plqe5Wev"    |
    Given I wait until the status of deployment "hooks" becomes :complete
    Given I obtain test data file "deployment/updatev1.json"
    When I run the :replace client command with:
      | f | updatev1.json |
    Then the step should succeed
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "type": "Rolling"         |
      | "type": "ImageChange"     |
      | "replicas": 2             |
      | "value": "Plqe5Wevchange" |
    Given I wait until the status of deployment "hooks" becomes :complete
    When I run the :rollback client command with:
      | deployment_name         | hooks-1                   |
      | change_triggers         |                           |
      | change_scaling_settings | <change_scaling_settings> |
      | change_strategy         | <change_strategy>         |
    Then the output should contain:
      | #3 rolled back to hooks-1 |
    And the pod named "hooks-3-deploy" becomes ready
    Given I wait for the pod named "hooks-3-deploy" to die
    When I get project pod
    Then the output should match:
      | READY\\s+STATUS |
      | 1/1\\s+Running  |
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "type": "ConfigChange" |
      | "value": "Plqe5Wev"    |
      | <changed_val1>         |
      | <changed_val2>         |
    Examples:
      | change_scaling_settings | change_strategy | changed_val1  | changed_val2       |
      | :false                  | :false          |               |                    | # @case_id OCP-12116
      |                         | :false          | "replicas": 1 |                    | # @case_id OCP-12018
      |                         |                 | "replicas": 1 | "type": "Recreate" | # @case_id OCP-12624

  # @author xxing@redhat.com
  # @case_id OCP-11877
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: CLI rollback with one component
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "type": "Recreate"     |
      | "type": "ConfigChange" |
      | "replicas": 1          |
      | "value": "Plqe5Wev"    |
    Given I obtain test data file "deployment/updatev1.json"
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :replace client command with:
      | f | updatev1.json |
    Then the step should succeed
    """
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "type": "Rolling"         |
      | "type": "ImageChange"     |
      | "replicas": 2             |
      | "value": "Plqe5Wevchange" |
    When I run the :rollback client command with:
      | deployment_name         | hooks-1 |
    Then the output should contain:
      | #3 rolled back to hooks-1                            |
      | Warning: the following images triggers were disabled |
      | You can re-enable them with |
    And the pod named "hooks-3-deploy" becomes ready
    Given I wait for the pod named "hooks-3-deploy" to die
    When I get project pod
    Then the output should match:
      | READY\\s+STATUS |
      | (Running)?(Pending)?  |
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "value": "Plqe5Wev"    |

  # @author pruan@redhat.com
  # @case_id OCP-12133
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Can't stop a deployment in Failed status
    Given I have a project
    Given I obtain test data file "deployment/test-stop-failed-deployment.json"
    When I run the :create client command with:
      | f | test-stop-failed-deployment.json |
    When the pod named "test-stop-failed-deployment-1-deploy" becomes ready
    When  I run the :rollout_cancel client command with:
      | resource | deploymentConfig            |
      | name     | test-stop-failed-deployment |
    Then the step should succeed
    Given I wait up to 40 seconds for the steps to pass:
    """
    When  I run the :describe client command with:
      | resource | dc                           |
      | name     | test-stop-failed-deployment  |
    Then the step should succeed
    Then the output by order should match:
      | Deployment #1      |
      | Status:\\s+Failed  |
    """
    When  I run the :rollout_cancel client command with:
      | resource | deploymentConfig            |
      | name     | test-stop-failed-deployment |
    Then the step should succeed
    And the output should contain:
      | No rollout is in progress |
    When I run the :rollout_status client command with:
      | resource | deploymentConfig            |
      | name     | test-stop-failed-deployment |
    Then the output should match:
      | was cancelled |

  # @author pruan@redhat.com
  # @case_id OCP-12246
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Stop a "Running" deployment
    Given I have a project
    Given I obtain test data file "deployment/dc-with-pre-mid-post.yaml"
    When I run the :create client command with:
      | f | dc-with-pre-mid-post.yaml |
    And I wait until the status of deployment "hooks" becomes :running
    And I wait up to 60 seconds for the steps to pass:
    """
    When I run the :rollout_cancel client command with:
      | resource | deploymentConfig   |
      | name     | hooks              |
    """
    And I wait until the status of deployment "hooks" becomes :failed
    When I run the :rollout_retry client command with:
      | resource | deploymentConfig   |
      | name     | hooks              |
    Then the step should succeed
    Then the output should match:
      | retried rollout |
    And I wait until the status of deployment "hooks" becomes :complete

  # @author cryan@redhat.com
  # @case_id OCP-10648
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Rollback via CLI when previous version failed
    Given I have a project
    When I run the :create_deploymentconfig client command with:
      | image | quay.io/openshifttest/hello-openshift@sha256:424e57db1f2e8e8ac9087d2f5e8faea6d73811f0b6f96301bc94293680897073 |
      | name  | mydc                  |
    Then the step should succeed
    And I wait until the status of deployment "mydc" becomes :complete

    # Workaround: the below steps make a failed deployment instead of --cancel
    Given I successfully patch resource "dc/mydc" with:
      | {"spec":{"strategy":{"rollingParams":{"pre":{ "execNewPod": { "command": [ "/bin/false" ]}, "failurePolicy": "Abort" }}}}} |
    When I run the :rollout_latest client command with:
      | resource | mydc  |
    Then the step should succeed
    And the output should contain "rolled out"
    And I wait until the status of deployment "mydc" becomes :failed

    # Remove the pre-hook introduced by the above workaround,
    # otherwise later deployment will always fail
    Given I successfully patch resource "dc/mydc" with:
      | {"spec":{"strategy":{"rollingParams":{"pre":null}}}} |
    When I run the :rollback client command with:
      | deployment_name   | mydc |
    Then the step should succeed
    # Deployment #3
    And the output should contain "rolled back to mydc-1"

  # @author pruan@redhat.com
  # @case_id OCP-12528
  @inactive
  Scenario: Make multiple deployment by oc deploy
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    And I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    And I check that the "hooks" deployment_config exists in the project
    When I run the :rollout_latest client command with:
      | resource | hooks |
    Then the step should fail
    And the output should contain:
      | error       |
      | in progress |
    Given I wait for the pod named "hooks-1-deploy" to die
    When I run the :rollout_latest client command with:
      | resource | hooks |
    Then the step should succeed
    # Given I wait for the pod named "hooks-2-deploy" to die
    And I check that the "hooks" deployment_config exists in the project

  # @author xiaocwan@redhat.com
  # @case_id OCP-10717
  @inactive
  Scenario: View the logs of the latest deployment
    # check deploy log when deploying
    Given I have a project
    When I run the :run client command with:
      |  name  | hooks                                                     |
      | image  | <%= project_docker_repo %>openshift/hello-openshift:latest|
    Then the step should succeed
    When I run the :logs client command with:
      | resource_name | dc/hooks |
      | f             |          |
    Then the output should match:
      | caling.*to\\s+1 |

    And I wait until the status of deployment "hooks" becomes :complete
    And I run the :logs client command with:
      | resource_name | dc/hooks |
    Then the step should succeed
    And the output should contain "erving"

    # check for non-existent dc
    When I run the :logs client command with:
      | resource_name | dc/nonexistent |
    Then the step should fail
    And the output should match:
      | [Dd]eploymentconfigs.*not found |

  # @author yinzhou@redhat.com
  # @case_id OCP-9563
  @gcp-upi
  @gcp-ipi
  @aws-upi
  Scenario: A/B Deployment
    Given I have a project
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/deployment-example@sha256:0631a0c7aee3554391156d991138af4b00e9a724f9c5813f4079930c8fc0d16b |
      | name         | ab-example-a                                                                                                     |
      | l            | ab-example=true                                                                                                  |
      | env          | SUBTITLE=shardA                                                                                                  |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | deploymentconfig |
      | resource_name | ab-example-a     |
      | name          | ab-example       |
      | selector      | ab-example=true  |
    Then the step should succeed
    When I expose the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardA"
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/deployment-example@sha256:0631a0c7aee3554391156d991138af4b00e9a724f9c5813f4079930c8fc0d16b |
      | name         | ab-example-b                                                                                                     |
      | l            | ab-example=true                                                                                                  |
      | env          | SUBTITLE=shardB                                                                                                  |
    Then the step should succeed
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-a     |
      | replicas | 0                |
    Then the step should succeed
    Given number of replicas of "ab-example-a" deployment config becomes:
      | desired   | 0 |
      | current   | 0 |
      | updated   | 0 |
      | available | 0 |
    When I use the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardB"
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-b     |
      | replicas | 0                |
    Then the step should succeed
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-a     |
      | replicas | 1                |
    Then the step should succeed
    Given number of replicas of "ab-example-a" deployment config becomes:
      | desired   | 1 |
      | current   | 1 |
      | updated   | 1 |
      | available | 1 |
    When I use the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardA"

  # @author yinzhou@redhat.com
  # @case_id OCP-9566
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Blue-Green Deployment
    Given I have a project
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/deployment-example:v1 |
      | name         | bluegreen-example-old                       |
    Then the step should succeed
    When I run the :new_app client command with:
      | docker_image | quay.io/openshifttest/deployment-example:v2 |
      | name         | bluegreen-example-new                       |
    Then the step should succeed
    #When I expose the "bluegreen-example-old" service
    When I run the :expose client command with:
      | resource      | svc                   |
      | resource_name | bluegreen-example-old |
      | name          | bluegreen-example     |
    Then the step should succeed
    #And I wait for a web server to become available via the route
    When I use the "bluegreen-example-old" service
    And I wait for a web server to become available via the "bluegreen-example" route
    And the output should contain "v1"
    And I replace resource "route" named "bluegreen-example":
      | name: bluegreen-example-old | name: bluegreen-example-new |
    Then the step should succeed
    When I use the "bluegreen-example-new" service
    And I wait for the steps to pass:
    """
    And I wait for a web server to become available via the "bluegreen-example" route
    And the output should contain "v2"
    """

  # @author pruan@redhat.com
  # @case_id OCP-12532
  @inactive
  Scenario: Manually start deployment by oc deploy
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | hooks |
    Then the step should succeed
    And I check that the "hooks" deployment_config exists in the project

  # @author yinzhou@redhat.com
  # @case_id OCP-12468
  @inactive
  Scenario: Pre and post deployment hooks
    Given I have a project
    Given I obtain test data file "deployment/testhook.json"
    When I run the :create client command with:
      | f | testhook.json |
    Then the step should succeed
    When the pod named "hooks-1-hook-pre" becomes ready
    And I get project pod named "hooks-1-hook-pre" as YAML
    And the output should match:
      | mountPath:\\s+/var/lib/origin |
      | emptyDir:                     |
      | name:\\s+dataem               |
    When the pod named "hooks-1-hook-post" becomes ready
    And I get project pod named "hooks-1-hook-post" as YAML
    And the output should match:
      | mountPath:\\s+/var/lib/origin |
      | emptyDir:                     |
      | name:\\s+dataem               |

  # @author yinzhou@redhat.com
  # @case_id OCP-10724
  @inactive
  Scenario: deployment hook volume inheritance that volume name was null
    Given I have a project
    Given I obtain test data file "deployment/ocp10724/hooks-null-volume.json"
    When I run the :create client command with:
      | f | hooks-null-volume.json |
    Then the step should fail
    And the output should contain "must not be empty"

  # @author yadu@redhat.com
  # @case_id OCP-9567
  @smoke
  @inactive
  Scenario: Recreate deployment strategy
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/deployment/recreate-example.yaml |
    Then the step should succeed
    And I wait until the status of deployment "recreate-example" becomes :complete
    When I use the "recreate-example" service
    And I wait for a web server to become available via the "recreate-example" route
    Then the output should contain:
      | v1 |
    When I run the :tag client command with:
      | source | recreate-example:v2     |
      | dest   | recreate-example:latest |
    Then the step should succeed
    And I wait until the status of deployment "recreate-example" becomes :complete
    When I use the "recreate-example" service
    And I wait for a web server to become available via the "recreate-example" route
    Then the output should contain:
      | v2 |

  # @author pruan@redhat.com
  # @case_id OCP-11939
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: start deployment when the latest deployment is completed
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    And I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    And I replace resource "dc" named "hooks" saving edit to "tmp_out.yaml":
      | replicas: 1 | replicas: 2 |
    Then the step should succeed
    And I wait until the status of deployment "hooks" becomes :complete
    And I get project rc as JSON
    Then the expression should be true> @result[:parsed]['items'][0]['status']['replicas'] == 2

  # @author pruan@redhat.com
  # @case_id OCP-12056
  @inactive
  Scenario: Manual scale dc will update the deploymentconfig's replicas
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    And I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | dc    |
      | name     | hooks |
      | replicas | 2     |
    Then the step should succeed
    When I get project dc named "hooks" as JSON
    Then the expression should be true> @result[:parsed]['spec']['replicas'] == 2

    When I run the :rollout_latest client command with:
      | resource | hooks |
    And I wait until number of replicas match "2" for replicationController "hooks-1"
    Then I run the :scale client command with:
      | resource | dc    |
      | name     | hooks |
      | replicas | 1     |
    And I wait until number of replicas match "1" for replicationController "hooks-1"

  # @author pruan@redhat.com
  # @case_id OCP-10728
  @inactive
  Scenario: Inline deployer hook logs
    Given I have a project
    Given I obtain test data file "deployment/Inline-logs.json"
    And I run the :create client command with:
      | f | Inline-logs.json |
    And I run the :logs client command with:
      | f             | true     |
      | resource_name | dc/hooks |
    Then the output should contain:
      | pre:                                 |
      | Can't read /etc/scl/prefixes/mysql55 |
      | pre: Success                         |
      | post:                                |
      | Can't read /etc/scl/prefixes/mysql55 |
      | post: Success                        |

  # @author yinzhou@redhat.com
  # @case_id OCP-11769
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Start new deployment when deployment running
    Given I have a project
    Given I obtain test data file "deployment/dc-with-pre-mid-post.yaml"
    When I run the :create client command with:
      | f | dc-with-pre-mid-post.yaml |
    Then the step should succeed
    Given I wait until the status of deployment "hooks" becomes :running
    And I replace resource "dc" named "hooks":
      | latestVersion: 1 | latestVersion: 2 |
    Then the step should succeed
    Given  I wait up to 60 seconds for the steps to pass:
    """
    When I run the :rollout_status client command with:
      | resource | deploymentConfig |
      | name     | hooks            |
    Then the output should match "new replicas have been updated"
    """

  # @author cryan@redhat.com
  # @case_id OCP-12151
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: When the latest deployment failed auto rollback to the active deployment
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Given a pod becomes ready with labels:
    | deployment=hooks-1 |
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | hooks            |
      | replicas | 2                |
    Given I wait until number of replicas match "2" for replicationController "hooks-1"
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | hooks            |
      | replicas | 1                |
    Given I wait until number of replicas match "1" for replicationController "hooks-1"
    When I run the :rollout_latest client command with:
      | resource | hooks |
    Then the step should succeed
    Given the pod named "hooks-2-deploy" becomes present
    When I run the :patch client command with:
      | resource      | pod                                   |
      | resource_name | hooks-2-deploy                        |
      | p             | {"spec":{"activeDeadlineSeconds": 5}} |
    Then the step should succeed
    When I run the :patch client command with:
      | resource      |dc                        |
      | resource_name | hooks                    |
      | p             | {"spec":{"replicas": 2}} |
    Then the step should succeed
    When I get project pod named "hooks-2-deploy" as JSON
    Then the output should contain ""activeDeadlineSeconds": 5"
    When I get project dc named "hooks" as JSON
    Then the output should contain ""replicas": 2"
    Given all existing pods die with labels:
      | deployment=hooks-2 |
    When I get project pods with labels:
      | l | deployment=hooks-2 |
    Then the output should not contain "hooks-2"
    Given a pod becomes ready with labels:
      | deployment=hooks-1 |
    Given I wait up to 60 seconds for the steps to pass:
    """
    When I get project pods
    And the output should match:
      | DeadlineExceeded\|Error |
      | hooks-1                 |
    """

  # @author yinzhou@redhat.com
  # @case_id OCP-10617
  @admin
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: DeploymentConfig should allow valid value of resource requirements
    Given I have a project
    Given I obtain test data file "quota/limits.yaml"
    When I run the :create admin command with:
      | f | limits.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    Given I obtain test data file "quota/quota.yaml"
    When I run the :create admin command with:
      | f | quota.yaml |
      | n | <%= project.name %> |
    Then the step should succeed
    Given I obtain test data file "deployment/deployment-with-resources.json"
    When I run the :create client command with:
      | f | deployment-with-resources.json |
      | n | <%= project.name %> |
    Then the step should succeed
    And I wait for the steps to pass:
    """
    When I get project pod named "hooks-1-deploy" as YAML
    Then the output should match:
      | \\s+limits:\n\\s+cpu: 30m\n\\s+memory: 150Mi\n   |
      | \\s+requests:\n\\s+cpu: 30m\n\\s+memory: 150Mi\n |
    """
    And I wait until the status of deployment "hooks" becomes :complete
    And I wait for the steps to pass:
    """
    When I get project pod as YAML
    Then the output should match:
      | \\s+limits:\n\\s+cpu: 400m\n\\s+memory: 200Mi\n   |
      | \\s+requests:\n\\s+cpu: 400m\n\\s+memory: 200Mi\n |
    """

  # @author yinzhou@redhat.com
  # @case_id OCP-11221
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Scale up when deployment running
    Given I have a project
    When I run the :create_deploymentconfig client command with:
      | image | quay.io/openshifttest/deployment-example@sha256:0631a0c7aee3554391156d991138af4b00e9a724f9c5813f4079930c8fc0d16b |
      | name  | deployment-example                                                                                               |
    Then the step should succeed
    And I wait until the status of deployment "deployment-example" becomes :complete
    When I run the :rollout_latest client command with:
      | resource | deployment-example |
    Then the step should succeed
    Then I run the :scale client command with:
      | resource | deploymentconfig   |
      | name     | deployment-example |
      | replicas | 2                  |
    Then the step should succeed
    And I wait until the status of deployment "deployment-example" becomes :complete
    When I get project dc named "deployment-example" as JSON
    Then the expression should be true> @result[:parsed]['spec']['replicas'] == 2

  # @author qwang@redhat.com
  # @case_id OCP-12356
  @inactive
  Scenario: configchange triggers deploy automatically
    Given I have a project
    Given I obtain test data file "deployment/deployment1.json"
    When I run the :create client command with:
      | f | deployment1.json |
    Then the step should succeed
    Given status becomes :succeeded of exactly 1 pods labeled:
      | name=hello-openshift |
    When I run the :set_env client command with:
      | resource | dc/hooks                   |
      | e        | MYSQL_PASSWORD=update12345 |
    Then the step should succeed
    When I get project dc named "hooks" as JSON
    Then the output should contain:
      | "latestVersion": 2 |
    Given I wait until number of replicas match "0" for replicationController "hooks-1"
    Then I wait for the "hooks-2" rc to appear
    And I wait until number of replicas match "1" for replicationController "hooks-2"
    Given I wait up to 60 seconds for the steps to pass:
    """
    When I run the :get client command with:
     | resource | po    |
    Then the step should succeed
    And the output should match:
     | hooks-2.*Running |
    """

  # @author yinzhou@redhat.com
  # @case_id OCP-11326
  @smoke
  Scenario: Support verbs of Deployment in OpenShift
    Given I have a project
    Given I obtain test data file "deployment/extensions/deployment.yaml"
    When I run the :create client command with:
      | f | deployment.yaml |
    Then the step should succeed
    When I run the :scale client command with:
      | resource | deployment      |
      | name     | hello-openshift |
      | replicas | 2               |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deployment         |
      | resource_name | hello-openshift    |
      | template      | {{.spec.replicas}} |
    Then the output should match "2"
    When I run the :scale client command with:
      | resource | deployment      |
      | name     | hello-openshift |
      | replicas | 1               |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deployment         |
      | resource_name | hello-openshift    |
      | template      | {{.spec.replicas}} |
    Then the output should match "1"
    When I run the :rollout_pause client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the step should succeed
    When I run the :set_env client command with:
      | resource | deployment/hello-openshift |
      | e        | key=value                  |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deployment      |
      | resource_name | hello-openshift |
      | o             | yaml            |
    And the expression should be true> @result[:parsed]['metadata']['annotations']['deployment.kubernetes.io/revision'] == "1"
    And the expression should be true> @result[:parsed]['spec']['paused'] == true
    And the expression should be true> @result[:parsed]['spec']['template']['spec']['containers'][0]['env'].include?({"name"=>"key", "value"=>"value"})
    When I run the :set_env client command with:
      | resource | pods |
      | all      | true |
      | list     | true |
    And the output should not contain:
      | key=value      |
    When I run the :rollout_resume client command with:
      | resource | deployment      |
      | name     | hello-openshift |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | deployment                |
      | resource_name | hello-openshift           |
      | template      | {{.metadata.annotations}} |
    Then the step should succeed
    And the output should contain:
      | deployment.kubernetes.io/revision:2 |
    Given I wait up to 60 seconds for the steps to pass:
    """
    When I run the :set_env client command with:
      | resource | pods |
      | all      | true |
      | list     | true |
    And the output should contain:
      | key=value |
    """
    When I run the :get client command with:
      | resource      | deployment                |
      | resource_name | hello-openshift           |
      | template      | {{.metadata.annotations}} |
    Then the step should succeed
    And the output should contain:
      | deployment.kubernetes.io/revision:2 |

  # @author mcurlej@redhat.com
  # @case_id OCP-10902
  @smoke
  @inactive
  Scenario: Auto cleanup old RCs
    Given I have a project
    Given I obtain test data file "deployment/ocp10902/history-limit-dc.yaml"
    When I run the :create client command with:
      | f | history-limit-dc.yaml |
    Then the step should succeed
    When I run the steps 3 times:
    """
    When I run the :set_env client command with:
      | resource | dc/history-limit |
      | e        | TEST#{cb.i}=1    |
    Then the step should succeed
    And I wait until the status of deployment "history-limit" becomes :complete
    """
    When I run the :rollback client command with:
      | deployment_name | history-limit |
      | to_version      | 1             |
    Then the step should fail
    And the output should contain:
      | couldn't find deployment for rollback  |
    When I run the :set_env client command with:
      | resource | dc/history-limit |
      | e        | TEST4=4          |
    Then the step should succeed
    And I wait until the status of deployment "history-limit" becomes :complete
    And I wait for the steps to pass:
    """
    When I get project rc
    Then the output should not contain "history-limit-2"
    """

  # @author haowang@redhat.com
  # @case_id OCP-16443
  @aws-ipi
  @proxy
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: Trigger info is retained for deployment caused by image changes 37 new feature
    Given the master version >= "3.7"
    Given I have a project
    When I process and create "https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json"
    Then the step should succeed
    Given the "ruby-sample-build-1" build was created
    And the "ruby-sample-build-1" build completed
    Given I wait until the status of deployment "frontend" becomes :complete
    When I get project dc named "frontend" as YAML
    Then the output by order should match:
      | causes:                |
      | - type: ConfigChange   |
      | message: config change |

  # @author yinzhou@redhat.com
  # @case_id OCP-31200
  @aws-ipi
  @gcp-upi
  @gcp-ipi
  @4.10 @4.9
  @aws-upi
  @vsphere-ipi
  @4.9
  @azure-ipi
  Scenario: A/B Deployment for OCP 4.5 or greater
    Given the master version >= "4.5"
    Given I have a project
    When I run the :new_app client command with:
      | docker_image         | quay.io/openshifttest/deployment-example |
      | name                 | ab-example-a                             |
      | as_deployment_config | true                                     |
      | l                    | ab-example=true                          |
      | env                  | SUBTITLE=shardA                          |
    Then the step should succeed
    When I run the :expose client command with:
      | resource      | deploymentconfig |
      | resource_name | ab-example-a     |
      | name          | ab-example       |
      | selector      | ab-example=true  |
    Then the step should succeed
    When I expose the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardA"
    When I run the :new_app client command with:
      | docker_image         | quay.io/openshifttest/deployment-example |
      | name                 | ab-example-b                             |
      | as_deployment_config | true                                     |
      | l                    | ab-example=true                          |
      | env                  | SUBTITLE=shardB                          |
    Then the step should succeed
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-a     |
      | replicas | 0                |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "ab-example-a-1"
    When I use the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardB"
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-b     |
      | replicas | 0                |
    Then the step should succeed
    Then I run the :scale client command with:
      | resource | deploymentconfig |
      | name     | ab-example-a     |
      | replicas | 1                |
    Then the step should succeed
    Given I wait until number of replicas match "0" for replicationController "ab-example-b-1"
    Given I wait until number of replicas match "1" for replicationController "ab-example-a-1"
    When I use the "ab-example" service
    Then I wait for a web server to become available via the "ab-example" route
    And the output should contain "shardA"

