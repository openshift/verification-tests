Feature: jenkins.feature

  # @author cryan@redhat.com
  Scenario Outline: Trigger build of application from jenkins job with ephemeral volume
    Given I have a project
    And I have a jenkins v<ver> application
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/application-template.json |
    When I give project edit role to the default service account
    Then the step should succeed
    Given a pod becomes ready with labels:
      | name=jenkins |
    When I execute on the pod:
      |  id | -u |
    Then the step should succeed
    #Check that the user is not root, or 0 id
    #The regex below should match any number greater than 0
    And the output should match "^[1-9][0-9]*$"
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
      | <%= env.version_gt("3.2", user: user) ? "name" : "app" %>=frontend |
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
      | 1   | # @case_id OCP-11156
      | 2   | # @case_id OCP-11368

  # @author cryan@redhat.com
  @smoke
  Scenario Outline: Trigger build of application from jenkins job with persistent volume
    Given I have a project
    And I have a jenkins v<ver> application
    When I run the :patch client command with:
      | resource      | pvc                                                                             |
      | resource_name | jenkins                                                                         |
      | p             | {"metadata":{"annotations":{"volume.alpha.kubernetes.io/storage-class":"foo"}}} |
    Then the step should succeed
    And the "jenkins" PVC becomes :bound within 300 seconds
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image/language-image-templates/application-template.json |
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
      | 1   | # @case_id OCP-11179
      | 2   | # @case_id OCP-11369

  # @author cryan@redhat.com xiuwang@redhat.com
  Scenario Outline: Make jenkins slave configurable when do jenkinspipeline strategy with maven slave
    Given I have a project
    And I have a jenkins v<version> application
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/pipeline/maven-pipeline.yaml |
    Then the step should succeed
    Given I have a jenkins browser
    And I log in to jenkins
    Given I update "maven" slave image for jenkins <version> server
    When I run the :start_build client command with:
      | buildconfig | openshift-jee-sample |
    Then the step should succeed
    Given a pod becomes ready with labels:
      | jenkins/maven=true |
    Given the "openshift-jee-sample-1" build completes
    When I perform the :goto_jenkins_buildlog_page web action with:
      | namespace|<%= project.name %>                      |
      | job_name| <%= project.name %>-openshift-jee-sample |
      | job_num | 1                                        |
    Then the step should succeed
    When I get the visible text on web html page
    Then the output should contain:
      | Building SampleApp 1.0 |
      | BUILD SUCCESS          |
    When I run the :patch client command with:
      | resource      | bc                                                                                                                                       |
      | resource_name | openshift-jee-sample                                                                                                                     |
      | p             | {"spec" : {"strategy": {"jenkinsPipelineStrategy": {"jenkinsfile": "node('unexist') {\\nstage 'Check mvn version'\\nsh 'mvn -v'\\n}"}}}} |
    Then the step should succeed
    When I perform the :jenkins_add_pod_template web action with:
      | slave_name  | unexist        |
      | slave_label | unexist        |
      | slave_image | unexist:latest |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | openshift-jee-sample |
    Then the step should succeed
    When I perform the :jenkins_verify_job_text web action with:
      | namespace  | <%= project.name %>                      |
      | job_name   | <%= project.name %>-openshift-jee-sample |
      | checktext  | unexist         |
      | job_num    | 2               |
      | time_out   | 300             |
    Then the step should succeed

    Examples:
      | version |
      | 1       | # @case_id OCP-10896
      | 2       | # @case_id OCP-10980

  # @author cryan@redhat.com
  Scenario Outline: Delete resource using jenkins pipeline DSL
    Given I have a project
    And I have a jenkins v<ver> application
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/application-template.json |
    Then the step should succeed
    When I run the :policy_add_role_to_user client command with:
      | role      | admin                                           |
      | user_name | system:serviceaccount:<%=project.name%>:default |
    Then the step should succeed
    When I run the :start_build client command with:
      | buildconfig | frontend |
    Then the step should succeed
    Given I have a jenkins browser
    And I log in to jenkins
    When I perform the :jenkins_create_pipeline_job web action with:
      | job_name | openshifttest |
    Then the step should succeed
    Given I download a file from "https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/OCP_12075/pipeline_delete_resource.groovy"
    And I replace lines in "pipeline_delete_resource.groovy":
      | <repl_env> | <%= env.api_endpoint_url %> |
      | <repl_ns>  | <%= project.name %>         |
    # The use of the 'dump' method in dsl_text escapes the groovy content to be
    # used by watir/selenium.
    When I perform the :jenkins_pipeline_insert_script web action with:
      | job_name        | openshifttest                                            |
      | editor_position | row: 1, column: 1                                        |
      | dsl_text        | <%= File.read('pipeline_delete_resource.groovy').dump %> |
    Then the step should succeed
    When I perform the :jenkins_build_now web action with:
      | job_name | openshifttest |
    Then the step should succeed
    When I perform the :jenkins_verify_job_success web action with:
      | job_name   | openshifttest |
      | job_number | 1             |
      | time_out   | 60            |
    Then the step should succeed
    Given I get project dc named "frontend"
    Then the output should contain "not found"
    Given I get project builds
    Then the output should contain "No resources found"
    Given I get project is
    Then the output should not match "origin-nodejs-sample\s+latest"
    Examples:
      | ver |
      | 1   | # @case_id OCP-12075
      | 2   | # @case_id OCP-12094

  # @author xiuwang@redhat.com
  # @case_id OCP-12773
  Scenario: OCP-12773 new-app/new-build support for pipeline buildconfigs
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
    When I run the :new_app client command with:
      | file | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/OCP-13259/samplepipeline.yaml |
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
  Scenario: OCP-15384 Jenkins pipeline build with OpenShift Client Plugin Example
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
  # @case_id OCP-17357
  Scenario: OCP-17357 Explicitly set jdk version via env var in jenkins-2-rhel7
    Given I have a project
    When I run the :new_app client command with:
      | template | jenkins-ephemeral |
      | p        | MEMORY_LIMIT=1Gi  |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=jenkins         |
      | deployment=jenkins-1 |
    When I execute on the pod:
      | ls | -l | /etc/alternatives/java |
    Then the step should succeed
    And the output should contain:
      | i386 |
    When I run the :set_env client command with:
      | resource | dc/jenkins                      |
      | e        | OPENSHIFT_JENKINS_JVM_ARCH=i386 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=jenkins         |
      | deployment=jenkins-2 |
    When I run the :describe client command with:
      | resource | pod             |
      | name     | <%= pod.name %> |
    Then the step should succeed
    And the output should contain:
      | OPENSHIFT_JENKINS_JVM_ARCH:\s+i386|
    When I execute on the pod:
      | ls | -l | /etc/alternatives/java |
    Then the step should succeed
    And the output should contain:
      | i386 |
    And the project is deleted
    Given I have a project
    When I run the :new_app client command with:
      | template | jenkins-ephemeral |
      | p        | MEMORY_LIMIT=3Gi  |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=jenkins         |
      | deployment=jenkins-1 |
    When I execute on the pod:
      | ls | -l | /etc/alternatives/java |
    Then the step should succeed
    And the output should contain:
      | x86_64 |
    When I run the :set_env client command with:
      | resource | dc/jenkins                      |
      | e        | OPENSHIFT_JENKINS_JVM_ARCH=i386 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=jenkins         |
      | deployment=jenkins-2 |
    When I execute on the pod:
      | ls | -l | /etc/alternatives/java |
    Then the step should succeed
    And the output should contain:
      | i386 |
    When I run the :set_env client command with:
      | resource | dc/jenkins                        |
      | e        | OPENSHIFT_JENKINS_JVM_ARCH=x86_64 |
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=jenkins         |
      | deployment=jenkins-3 |
    When I execute on the pod:
      | ls | -l | /etc/alternatives/java |
    Then the step should succeed
    And the output should contain:
      | x86_64 |

