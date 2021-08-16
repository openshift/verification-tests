Feature: jenkins.feature
  # @author cryan@redhat.com
  Scenario Outline: Trigger build of application from jenkins job with persistent volume
    Given I have a project
    And I have a jenkins v<ver> application
    And the "jenkins" PVC becomes :bound within 300 seconds
    Given I obtain test data file "image/language-image-templates/application-template.json"
    When I run the :new_app client command with:
      | file | application-template.json |
    When I give project edit role to the default service account
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=jenkins |
    When I execute on the pod:
      |  id | -u |
    Then the step should succeed
    #Check that the user is not root, or 0 id
    Then the expression should be true> Integer(@result[:response]) > 0
    Given I have a jenkins browser
    And I log in to jenkins
    When I perform the :jenkins_trigger_sample_openshift_build web action with:
      | job_name                 | OpenShift%20Sample          |
      | scaler_apiurl            | <%= env.api_endpoint_url %> |
      | scaler_namespace         | <%= project.name %>         |
      | builder_apiurl           | <%= env.api_endpoint_url %> |
      | builder_namespace        | <%= project.name %>         |
      | deploy_verify_apiurl     | <%= env.api_endpoint_url %> |
      | deploy_verify_namespace  | <%= project.name %>         |
      | service_verify_apiurl    | <%= env.api_endpoint_url %> |
      | service_verify_namespace | <%= project.name %>         |
      | image_tagger_apiurl      | <%= env.api_endpoint_url %> |
      | image_tagger_namespace   | <%= project.name %>         |
    Then the step should succeed
    When I perform the :jenkins_build_now web action with:
      | job_name | OpenShift%20Sample |
    Then the step should succeed
    Given the "frontend-1" build was created
    And the "frontend-1" build completes
    And a pod becomes ready with labels:
      | deploymentconfig=frontend |
    #Ensure the Jenkins job completes, wait for the frontend-prod pod
    And a pod becomes ready with labels:
      | deployment=frontend-prod-1 |
    And I get project services
    Then the output should contain:
      | frontend-prod |
      | frontend      |
      | jenkins       |
    Given I get project deploymentconfigs
    Then the output should contain:
      | frontend-prod |
      | frontend      |
      | jenkins       |
    Given I get project is
    Then the output should contain:
      | <%= project.name %>/nodejs-010-rhel7     |
      | <%= project.name %>/origin-nodejs-sample |
      | prod                                     |
    When I run the :describe client command with:
      | resource | builds     |
      | name     | frontend-1 |
    Then the step should succeed
    When I perform the :jenkins_build_now web action with:
      | job_name | OpenShift%20Sample |
    Then the step should succeed
    Given the "frontend-2" build was created
    And the "frontend-2" build completes
    Given I get project is
    Then the output should contain:
      | <%= project.name %>/nodejs-010-rhel7     |
      | <%= project.name %>/origin-nodejs-sample |
      | prod                                     |
    Examples:
      | ver |
      | 2   | # @case_id OCP-11369

  # @author xiuwang@redhat.com
  Scenario Outline: Make jenkins slave configurable when do jenkinspipeline strategy with maven slave
    Given I have a project
    And I have a jenkins v<version> application
    Given I have a jenkins browser
    And I log in to jenkins
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/pipeline/maven-pipeline.yaml |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | openshift-jee-sample |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | jenkins=slave |
    Given the "openshift-jee-sample-1" build completes

    Examples:
      | version |
      | 2       | # @case_id OCP-10980

  # @author xiuwang@redhat.com
  # @case_id OCP-12773
  Scenario: new-app/new-build support for pipeline buildconfigs
    Given I have a project
    When I run the :new_app client command with:
      | app_repo    | https://github.com/sclorg/nodejs-ex |
      | context_dir | openshift/pipeline |
      | name        | nodejs-ex-pipeline |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig        |
      | object_name_or_id | nodejs-ex-pipeline |
    Then the step should succeed

    #Create app from source that both contains jenkinsfile and Dockerfile
    When I run the :new_app client command with:
      | app_repo    | https://github.com/openshift-qe/nodejs-example#jenkinsfile_source |
      | context_dir | openshift/pipeline |
      | name        | nodejs-ex-pipeline1|
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline1 |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline1.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig         |
      | object_name_or_id | nodejs-ex-pipeline1 |
    Then the step should succeed

    #Create app from repo that contains valid source and jenkins file
    When I run the :new_app client command with:
      | app_repo | https://github.com/openshift-qe/nodejs-example#jenkinsfile_source |
      | name     | nodejs-ex-pipeline2                                               |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline2 |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline2.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig         |
      | object_name_or_id | nodejs-ex-pipeline2 |
    Then the step should succeed

    #Create app from source that contains jenkinsfile with explict pipeline strategy
    When I run the :new_app client command with:
      | app_repo    | https://github.com/sclorg/nodejs-ex |
      | context_dir | openshift/pipeline  |
      | name        | nodejs-ex-pipeline3 |
      | image_stream| nodejs:latest       |
      | strategy    | pipeline            |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline3 |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline3.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig         |
      | object_name_or_id | nodejs-ex-pipeline3 |
    Then the step should succeed

    When I run the :new_build client command with:
      | app_repo    | https://github.com/sclorg/nodejs-ex |
      | context_dir | openshift/pipeline |
      | name        | nodejs-ex-pipeline4|
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline4 |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline4.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig         |
      | object_name_or_id | nodejs-ex-pipeline4 |
    Then the step should succeed

    When I run the :new_build client command with:
      | app_repo    | https://github.com/openshift-qe/nodejs-example#jenkinsfile_source |
      | context_dir | openshift/pipeline |
      | name        | nodejs-ex-pipeline5|
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline5 |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline5.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig         |
      | object_name_or_id | nodejs-ex-pipeline5 |
    Then the step should succeed

    When I run the :new_build client command with:
      | app_repo | https://github.com/openshift-qe/nodejs-example#jenkinsfile_source |
      | name     | nodejs-ex-pipeline6                                               |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline6 |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline6.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig         |
      | object_name_or_id | nodejs-ex-pipeline6 |
    Then the step should succeed

    When I run the :new_build client command with:
      | app_repo    | https://github.com/sclorg/nodejs-ex |
      | context_dir | openshift/pipeline |
      | name        | nodejs-ex-pipeline7|
      | image_stream| nodejs:latest      |
      | strategy    | pipeline           |
    Then the step should succeed
    When I run the :get client command with:
      | resource | bc/nodejs-ex-pipeline7 |
    Then the step should succeed
    And the output should match "nodejs-ex-pipeline7.*JenkinsPipeline"
    When I run the :delete client command with:
      | object_type       | buildConfig         |
      | object_name_or_id | nodejs-ex-pipeline7 |
    Then the step should succeed

  # @author xiuwang@redhat.com
  # @case_id OCP-13259
  Scenario Outline: Add/update env vars to pipeline buildconfigs using jenkinsfile field
    Given I have a project
    And I have a jenkins v<version> application
    Given I obtain test data file "templates/OCP-13259/samplepipeline.yaml"
    When I run the :new_app client command with:
      | file | samplepipeline.yaml |
    Then the step should succeed
    Given I have a jenkins browser
    And I log in to jenkins
    When I run the :start_build client command with:
      | buildconfig | sample-pipeline |
    Then the step should succeed
    And the "sample-pipeline-1" build completes
    When I perform the :goto_jenkins_buildlog_page web action with:
      | namespace| <%= project.name %>                |
      | job_name| <%= project.name %>-sample-pipeline |
      | job_num | 1                                   |
    Then the step should succeed
    When I get the visible text on web html page
    Then the output should contain:
      | VAR1 = value1|
    When I run the :patch client command with:
      | resource      | bc                                                                                                                                  |
      | resource_name | sample-pipeline                                                                                                                     |
      | p             | {"spec":{"strategy":{"jenkinsPipelineStrategy":{"env":[{"name": "VAR1","value": "newvalue1"},{"name": "VAR2","value": "value2"}]}}}}|
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | sample-pipeline |
    Then the step should succeed
    When I perform the :jenkins_check_build_string_parameter web action with:
      | namespace| <%= project.name %>                 |
      | job_name | <%= project.name %>-sample-pipeline |
      | env_name | VAR1                                |
      | env_value| newvalue1                           |
    Then the step should succeed
    When I perform the :jenkins_check_build_string_parameter web action with:
      | namespace| <%= project.name %>                 |
      | job_name | <%= project.name %>-sample-pipeline |
      | env_name | VAR2                                |
      | env_value| value2                              |
    Then the step should succeed
    And the "sample-pipeline-2" build completes
    When I perform the :goto_jenkins_buildlog_page web action with:
      | namespace| <%= project.name %>                |
      | job_name| <%= project.name %>-sample-pipeline |
      | job_num | 2                                   |
    Then the step should succeed
    When I get the visible text on web html page
    Then the output should contain:
      | VAR1 = newvalue1|
      | VAR2 = value2|
    When I run the :patch client command with:
      | resource      | bc                                                                                             |
      | resource_name | sample-pipeline                                                                                |
      | p             | {"spec":{"strategy":{"jenkinsPipelineStrategy":{"env":[{"name": "VAR2","value": "value2"}]}}}} |
    Then the step should succeed
    When I perform the :jenkins_check_build_string_parameter web action with:
      | namespace| <%= project.name %>                 |
      | job_name | <%= project.name %>-sample-pipeline |
      | env_name | VAR1                                |
      | env_value| newvalue1                           |
    Then the step should fail

    Examples:
      | version |
      | 1       |
      | 2       |

  # @author xiuwang@redhat.com
  # @case_id OCP-15384
  Scenario: Jenkins pipeline build with OpenShift Client Plugin Example
    And I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/pipeline/openshift-client-plugin-pipeline.yaml |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=jenkins |
    Then evaluation of `pod.name` is stored in the :jenkins_pod clipboard
    And I run the :start_build client command with:
      | buildconfig | sample-pipeline-openshift-client-plugin |
    Then the step should succeed
    When the "sample-pipeline-openshift-client-plugin-1" build becomes :running
    And the "ruby-1" build becomes :running
    Then the "ruby-1" build completed
    Then the "sample-pipeline-openshift-client-plugin-1" build completed
    And a pod becomes ready with labels:
      | deploymentconfig=jenkins-second-deployment |
    When I execute on the "<%= cb.jenkins_pod %>" pod:
      | ps | ax | --columns | 1000 |
    Then the step should succeed
    And the output should contain:
      | /usr/bin/dumb-init -- /usr/libexec/s2i/run                             |
      | java -XX:+UseParallelGC -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 |

  # @author xiuwang@redhat.com
  # @case_id OCP-25401
  Scenario: Create jenkins application directly
    Given I have a project
    When I run the :new_app client command with:
      | image_stream | openshift/jenkins:2 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | deploymentconfig=jenkins |
    When I execute on the pod:
      |  ls | -la | /usr/bin/java |
    Then the step should succeed
    Then the output should contain:
      | /usr/bin/java -> /etc/alternatives/java |

  # @author xiuwang@redhat.com
  # @case_id OCP-35068
  @admin
  Scenario: Oauthaccesstoken should be deleted after loging out from Jenkins webconsole
    Given I have a project
    When I run the :new_app client command with:
      | template | jenkins-ephemeral |
    Then the step should succeed
    Given I wait for the "jenkins" service to become ready up to 300 seconds
    Given I have a browser with:
      | rules    | lib/rules/web/images/jenkins_2/                                   |
      | base_url | https://<%= route("jenkins", service("jenkins")).dns(by: user) %> |
    And I log in to jenkins
    When I run the :get admin command with:
      | resource | oauthaccesstoken |
    Then the step should succeed
    Then the output should contain:
      | jenkins-<%= project.name %> |
    When I run the :jenkins_logout web action
    Then the step should succeed
    When I run the :get admin command with:
      | resource | oauthaccesstoken |
    Then the step should succeed
    Then the output should not contain:
      | jenkins-<%= project.name %> |
