Feature: creating 'apps' with CLI

  # @author wsun@redhat.com
  # @case_id OCP-10593
  Scenario: OCP-10593 Could not create any context in non-existent project
    Given I create a new application with:
      | docker image | openshift/ruby-20-centos7~https://github.com/openshift/ruby-hello-world |
      | name         | myapp          |
      | n            | noproject      |
    Then the step should fail
    Then the output should match "User "<%=@user.name%>" cannot create imagestream.* in (project|the namespace) "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/hello-pod.json |
      | n | noproject |
    Then the step should fail
    Then the output should match "User "<%=@user.name%>" cannot create pods in (project|the namespace) "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/deployment/deployment1.json |
      | n | noproject |
    Then the step should fail
    Then the output should match "User "<%=@user.name%>" cannot create deploymentconfigs.* in (project|the namespace) "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-centos7.json |
      | n | noproject |
    Then the step should fail
    Then the output should match "User "<%=@user.name%>" cannot create imagestreams.* in (project|the namespace) "noproject""
    Given I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/application-template-stibuild.json |
      | n | noproject |
    Then the step should fail
    Then the output should match "User "<%=@user.name%>" cannot create templates.* in (project|the namespace) "noproject""

  # @author yinzhou@redhat.com
  # @case_id OCP-11761
  @admin
  Scenario: OCP-11761 Process with special FSGroup id can be ran when using RunAsAny as the RunAsGroupStrategy
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_special_fsGroup.json |
    Then the step should fail
    Given the following scc policy is created: https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/authorization/scc/scc-runasany.yaml
    Then the step should succeed
    When I run the :create admin command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/pods/pod_with_special_fsGroup.json |
      | n | <%= project.name %>                                                                                   |
    Then the step should succeed
    When the pod named "hello-openshift" becomes ready
    When I get project pod named "hello-openshift" as YAML
    Then the output by order should match:
      | securityContext: |
      | fsGroup: 0       |

  # @author cryan@redhat.com
  # @case_id OCP-12399
  Scenario: OCP-12399 Create an application from source code
    Given I have a project
    When I git clone the repo "https://github.com/openshift/ruby-hello-world"
    Then the step should succeed
    Given an 8 character random string of type :dns952 is stored into the :appname clipboard
    When I run the :new_app client command with:
      | app_repo     | ruby-hello-world                                        |
      | image_stream | openshift/ruby:latest                                   |
      | name         | <%= cb.appname %>                                       |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname %>-1 |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | localhost:8080 |
    Then the step should succeed
    """
    And the output should contain "Hello"
    And I delete all resources from the project
    #Check https github url
    Given an 8 character random string of type :dns952 is stored into the :appname1 clipboard
    When I run the :new_app client command with:
      | code         | https://github.com/openshift/ruby-hello-world           |
      | image_stream | openshift/ruby:2.5                                      |
      | name         | <%= cb.appname1 %>                                      |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname1 %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname1 %>-1 |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | localhost:8080 |
    Then the step should succeed
    """
    And the output should contain "Hello"
    And I delete all resources from the project
    #Check http github url
    Given an 8 character random string of type :dns952 is stored into the :appname2 clipboard
    When I run the :new_app client command with:
      | code         | http://github.com/openshift/ruby-hello-world            |
      | image_stream | openshift/ruby:2.5                                      |
      | name         | <%= cb.appname2 %>                                      |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname2 %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname2 %>-1 |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | localhost:8080 |
    Then the step should succeed
    """
    And the output should contain "Hello"
    And I delete all resources from the project
    #Check git github url
    Given an 8 character random string of type :dns952 is stored into the :appname3 clipboard
    When I run the :new_app client command with:
      | code         | git://github.com/openshift/ruby-hello-world             |
      | image_stream | openshift/ruby                                          |
      | name         | <%= cb.appname3 %>                                      |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Given the "<%= cb.appname3 %>-1" build completes
    Given 1 pods become ready with labels:
      | deployment=<%= cb.appname3 %>-1 |
    And I wait for the steps to pass:
    """
    When I execute on the pod:
      | curl | localhost:8080 |
    Then the step should succeed
    """
    And the output should contain "Hello"
    And I delete all resources from the project
    #Check master branch
    Given an 8 character random string of type :dns952 is stored into the :appname4 clipboard
    When I run the :new_app client command with:
      | code         | https://github.com/openshift/ruby-hello-world#master    |
      | image_stream | openshift/ruby                                          |
      | name         | <%= cb.appname4 %>                                      |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    When I run the :describe client command with:
      | resource | buildconfig |
      | name | <%= cb.appname4 %> |
    Then the output should match "Ref:\s+master"
    And I delete all resources from the project
    #Check invalid branch
    Given an 8 character random string of type :dns952 is stored into the :appname5 clipboard
    When I run the :new_app client command with:
      | code         | https://github.com/openshift/ruby-hello-world#invalid   |
      | image_stream | openshift/ruby                                          |
      | name         | <%= cb.appname5 %>                                      |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    Then the output should contain "error"
    And I delete all resources from the project
    #Check non-master branch
    Given an 8 character random string of type :dns952 is stored into the :appname6 clipboard
    When I run the :new_app client command with:
      | code         | https://github.com/openshift/ruby-hello-world#beta4     |
      | image_stream | openshift/ruby                                          |
      | name         | <%= cb.appname6 %>                                      |
      | env          | MYSQL_USER=test,MYSQL_PASSWORD=test,MYSQL_DATABASE=test |
    When I run the :describe client command with:
      | resource | buildconfig |
      | name | <%= cb.appname6 %> |
    Then the output should match "Ref:\s+beta4"
    And I delete all resources from the project
    #Check non-existing docker file
    Then I run the :new_app client command with:
      | app_repo | https://github.com/openshift-qe/sample-php |
      | strategy | docker                                     |
    Then the step should fail
    And the output should contain "No Dockerfile"
