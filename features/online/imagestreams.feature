Feature: ONLY ONLINE Imagestreams related scripts in this file

  # @author bingli@redhat.com
  # @case_id OCP-10509
  Scenario: OCP-10509 Check Online Pro default images
    When I run the :get client command with:
      | resource      | imagestreamtag  |
      | n             | openshift       |
    Then the step should succeed
    And the output should contain:
      | dotnet:1.0                              |
      | dotnet:latest                           |
      | dotnet:2.0                              |
      | dotnet:1.1                              |
      | dotnet-runtime:latest                   |
      | dotnet-runtime:2.0                      |
      | jboss-eap70-openshift:1.6               |
      | jboss-eap70-openshift:1.5               |
      | jboss-eap70-openshift:1.4               |
      | jboss-eap70-openshift:1.3               |
      | jboss-webserver30-tomcat7-openshift:1.2 |
      | jboss-webserver30-tomcat7-openshift:1.1 |
      | jboss-webserver30-tomcat7-openshift:1.3 |
      | jboss-webserver30-tomcat8-openshift:1.2 |
      | jboss-webserver30-tomcat8-openshift:1.1 |
      | jboss-webserver30-tomcat8-openshift:1.3 |
      | jboss-webserver31-tomcat7-openshift:1.0 |
      | jboss-webserver31-tomcat8-openshift:1.0 |
      | jenkins:1                               |
      | jenkins:2                               |
      | jenkins:latest                          |
      | mariadb:latest                          |
      | mariadb:10.1                            |
      | mongodb:2.4                             |
      | mongodb:latest                          |
      | mongodb:3.2                             |
      | mongodb:2.6                             |
      | mysql:latest                            |
      | mysql:5.7                               |
      | mysql:5.6                               |
      | mysql:5.5                               |
      | nodejs:6                                |
      | nodejs:latest                           |
      | mysql:5.5                               |
      | mysql:latest                            |
      | mysql:5.7                               |
      | mysql:5.6                               |
      | nodejs:0.10                             |
      | nodejs:4                                |
      | perl:latest                             |
      | perl:5.24                               |
      | perl:5.20                               |
      | perl:5.16                               |
      | php:latest                              |
      | php:7.0                                 |
      | php:5.6                                 |
      | php:5.5                                 |
      | postgresql:latest                       |
      | postgresql:9.5                          |
      | postgresql:9.4                          |
      | postgresql:9.2                          |
      | python:3.5                              |
      | python:3.4                              |
      | python:3.3                              |
      | python:2.7                              |
      | python:latest                           |
      | redhat-openjdk18-openshift:1.0          |
      | redhat-openjdk18-openshift:1.1          |
      | redis:latest                            |
      | redis:3.2                               |
      | ruby:latest                             |
      | ruby:2.4                                |
      | ruby:2.3                                |
      | ruby:2.2                                |
      | ruby:2.0                                |
      | wildfly:latest                          |
      | wildfly:10.1                            |
      | wildfly:10.0                            |
      | wildfly:9.0                             |
      | wildfly:8.1                             |

  # @author bingli@redhat.com
  # @case_id OCP-17285
  Scenario: OCP-17285 Check Online Starter default images
    When I run the :get client command with:
      | resource      | imagestreamtag  |
      | n             | openshift       |
    Then the step should succeed
    And the output should contain:
      | dotnet:latest                           |
      | dotnet:2.0                              |
      | dotnet:1.1                              |
      | dotnet:1.0                              |
      | dotnet-runtime:latest                   |
      | dotnet-runtime:2.0                      |
      | httpd:latest                            |
      | httpd:2.4                               |
      | jboss-webserver30-tomcat7-openshift:1.2 |
      | jboss-webserver30-tomcat7-openshift:1.1 |
      | jboss-webserver30-tomcat7-openshift:1.3 |
      | jboss-webserver30-tomcat8-openshift:1.3 |
      | jboss-webserver30-tomcat8-openshift:1.2 |
      | jboss-webserver30-tomcat8-openshift:1.1 |
      | jboss-webserver31-tomcat7-openshift:1.0 |
      | jboss-webserver31-tomcat8-openshift:1.0 |
      | jenkins:latest                          |
      | jenkins:1                               |
      | jenkins:2                               |
      | mariadb:latest                          |
      | mariadb:10.1                            |
      | mongodb:latest                          |
      | mongodb:3.2                             |
      | mongodb:2.6                             |
      | mongodb:2.4                             |
      | mysql:5.5                               |
      | mysql:latest                            |
      | mysql:5.7                               |
      | mysql:5.6                               |
      | nodejs:latest                           |
      | nodejs:0.10                             |
      | nodejs:4                                |
      | nodejs:6                                |
      | perl:latest                             |
      | perl:5.24                               |
      | perl:5.20                               |
      | perl:5.16                               |
      | php:latest                              |
      | php:7.0                                 |
      | php:5.6                                 |
      | php:5.5                                 |
      | postgresql:9.2                          |
      | postgresql:latest                       |
      | postgresql:9.5                          |
      | postgresql:9.4                          |
      | python:latest                           |
      | python:3.5                              |
      | python:3.4                              |
      | python:3.3                              |
      | python:2.7                              |
      | redhat-openjdk18-openshift:1.0          |
      | redhat-openjdk18-openshift:1.1          |
      | redis:latest                            |
      | redis:3.2                               |
      | ruby:latest                             |
      | ruby:2.4                                |
      | ruby:2.3                                |
      | ruby:2.2                                |
      | ruby:2.0                                |
      | wildfly:9.0                             |
      | wildfly:8.1                             |
      | wildfly:latest                          |
      | wildfly:10.1                            |
      | wildfly:10.0                            |

  # @author zhaliu@redhat.com
  Scenario Outline: ImageStream annotation and tag function
    Given I have a project
    And I attempt the registry route based on API url and store it in the :registry_route clipboard  
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/<file> |
    Then the step should succeed  
    When I have a skopeo pod in the project
    Then the step should succeed  
    And a pod becomes ready with labels:
      | name=skopeo |
    When I execute on the pod:  
      | skopeo                                                               |
      | --insecure-policy                                                    |
      | copy                                                                 |
      | --dcreds                                                             |
      | <%= user.name %>:<%= user.cached_tokens.first %>                  |
      | docker://docker.io/busybox                                           |
      | docker://<%= cb.registry_route %>/<%= project.name %>/<tag>          |
    Then the step should succeed  
    When I run the :get client command with:
      | resource | imagestreamtag |
      | template | <isttemplate>  |
    Then the step should succeed  
    And the output should match:
      | <istoutput> |
    When I run the :get client command with:
      | resource      | imagestream  |
      | resource_name | <isname>     |
      | template      | <istemplate> |
    Then the step should succeed
    And the output should match:
      | <isoutput> |
    Examples:
      | file             | tag         | isttemplate                                        | istoutput                                                  | isname  | istemplate                                                                               | isoutput                                         |
      | annotations.json | testa:prod  | {{range .items}} {{.metadata.annotations}} {{end}} | map\[color:blue\]                                          | testa   | "{{range .spec.tags}} {{.annotations}} {{end}}; {{range .status.tags}} {{.tag}} {{end}}" | map\[color:blue\].*prod\|prod.*map\[color:blue\] | # @case_id OCP-10090
      | busybox.json     | busybox:2.0 | "{{range .items}} {{.metadata.name}} {{end}}"      | busybox:latest.*busybox:2\.0\|busybox:2\.0.*busybox:latest | busybox | "{{range .status.tags}} {{.tag}} {{end}}"                                                | latest.*2\.0\|2\.0.*latest                       | # @case_id OCP-10093

