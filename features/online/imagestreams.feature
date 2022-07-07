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
      | apicast-gateway:2.5.0.GA                   |
      | apicast-gateway:latest                     |
      | apicast-gateway:2.1.0.GA                   |
      | apicast-gateway:2.2.0.GA                   |
      | apicast-gateway:2.3.0.GA                   |
      | apicast-gateway:2.4.0.GA                   |
      | apicurito-ui:1.2                           |
      | apicurito-ui:1.3                           |
      | cli:latest                                 |
      | cli-artifacts:latest                       |
      | dotnet:1.0                                 |
      | dotnet:1.1                                 |
      | dotnet:2.0                                 |
      | dotnet:2.1                                 |
      | dotnet:2.2                                 |
      | dotnet:latest                              |
      | dotnet-runtime:2.2                         |
      | dotnet-runtime:latest                      |
      | dotnet-runtime:2.0                         |
      | dotnet-runtime:2.1                         |
      | fis-java-openshift:1.0                     |
      | fis-java-openshift:2.0                     |
      | fis-karaf-openshift:1.0                    |
      | fis-karaf-openshift:2.0                    |
      | fuse-apicurito-generator:1.2               |
      | fuse-apicurito-generator:1.3               |
      | fuse7-console:1.0                          |
      | fuse7-console:1.1                          |
      | fuse7-console:1.2                          |
      | fuse7-console:1.3                          |
      | fuse7-eap-openshift:1.0                    |
      | fuse7-eap-openshift:1.1                    |
      | fuse7-eap-openshift:1.2                    |
      | fuse7-eap-openshift:1.3                    |
      | fuse7-java-openshift:1.0                   |
      | fuse7-java-openshift:1.1                   |
      | fuse7-java-openshift:1.2                   |
      | fuse7-java-openshift:1.3                   |
      | fuse7-karaf-openshift:1.0                  |
      | fuse7-karaf-openshift:1.1                  |
      | fuse7-karaf-openshift:1.2                  |
      | fuse7-karaf-openshift:1.3                  |
      | httpd:latest                               |
      | httpd:2.4                                  |
      | installer:latest                           |
      | installer-artifacts:latest                 |
      | java:11                                    |
      | java:8                                     |
      | java:latest                                |
      | jboss-decisionserver64-openshift:1.1       |
      | jboss-decisionserver64-openshift:1.2       |
      | jboss-decisionserver64-openshift:1.3       |
      | jboss-decisionserver64-openshift:1.4       |
      | jboss-decisionserver64-openshift:1.5       |
      | jboss-decisionserver64-openshift:1.0       |
      | jboss-fuse70-console:1.0                   |
      | jboss-fuse70-eap-openshift:1.0             |
      | jboss-fuse70-java-openshift:1.0            |
      | jboss-fuse70-karaf-openshift:1.0           |
      | jboss-processserver64-openshift:1.5        |
      | jboss-processserver64-openshift:1.0        |
      | jboss-processserver64-openshift:1.1        |
      | jboss-processserver64-openshift:1.2        |
      | jboss-processserver64-openshift:1.3        |
      | jboss-processserver64-openshift:1.4        |
      | jboss-webserver30-tomcat7-openshift:1.1    |
      | jboss-webserver30-tomcat7-openshift:1.2    |
      | jboss-webserver30-tomcat7-openshift:1.3    |
      | jboss-webserver30-tomcat8-openshift:1.1    |
      | jboss-webserver30-tomcat8-openshift:1.2    |
      | jboss-webserver30-tomcat8-openshift:1.3    |
      | jboss-webserver31-tomcat7-openshift:1.2    |
      | jboss-webserver31-tomcat7-openshift:1.3    |
      | jboss-webserver31-tomcat7-openshift:1.4    |
      | jboss-webserver31-tomcat7-openshift:1.0    |
      | jboss-webserver31-tomcat7-openshift:1.1    |
      | jboss-webserver31-tomcat8-openshift:1.0    |
      | jboss-webserver31-tomcat8-openshift:1.1    |
      | jboss-webserver31-tomcat8-openshift:1.2    |
      | jboss-webserver31-tomcat8-openshift:1.3    |
      | jboss-webserver31-tomcat8-openshift:1.4    |
      | jboss-webserver50-tomcat9-openshift:1.0    |
      | jboss-webserver50-tomcat9-openshift:1.1    |
      | jboss-webserver50-tomcat9-openshift:1.2    |
      | jboss-webserver50-tomcat9-openshift:latest |
      | jenkins:2                                  |
      | jenkins:latest                             |
      | jenkins-agent-maven:latest                 |
      | jenkins-agent-maven:v4.0                   |
      | jenkins-agent-nodejs:latest                |
      | jenkins-agent-nodejs:v4.0                  |
      | mariadb:10.1                               |
      | mariadb:10.2                               |
      | mariadb:latest                             |
      | modern-webapp:10.x                         |
      | modern-webapp:latest                       |
      | mongodb:3.2                                |
      | mongodb:3.4                                |
      | mongodb:3.6                                |
      | mongodb:latest                             |
      | mongodb:2.4                                |
      | mongodb:2.6                                |
      | must-gather:latest                         |
      | mysql:5.5                                  |
      | mysql:5.6                                  |
      | mysql:5.7                                  |
      | mysql:8.0                                  |
      | mysql:latest                               |
      | nginx:1.12                                 |
      | nginx:1.8                                  |
      | nginx:latest                               |
      | nginx:1.10                                 |
      | nodejs:6                                   |
      | nodejs:8                                   |
      | nodejs:8-RHOAR                             |
      | nodejs:latest                              |
      | nodejs:0.10                                |
      | nodejs:10                                  |
      | nodejs:4                                   |
      | openjdk-11-rhel7:1.0                       |
      | perl:5.16                                  |
      | perl:5.20                                  |
      | perl:5.24                                  |
      | perl:5.26                                  |
      | perl:latest                                |
      | php:5.6                                    |
      | php:7.0                                    |
      | php:7.1                                    |
      | php:7.2                                    |
      | php:latest                                 |
      | php:5.5                                    |
      | postgresql:9.2                             |
      | postgresql:9.4                             |
      | postgresql:9.5                             |
      | postgresql:9.6                             |
      | postgresql:latest                          |
      | postgresql:10                              |
      | python:2.7                                 |
      | python:3.3                                 |
      | python:3.4                                 |
      | python:3.5                                 |
      | python:3.6                                 |
      | python:latest                              |
      | redhat-openjdk18-openshift:1.0             |
      | redhat-openjdk18-openshift:1.1             |
      | redhat-openjdk18-openshift:1.2             |
      | redhat-openjdk18-openshift:1.3             |
      | redhat-openjdk18-openshift:1.4             |
      | redhat-openjdk18-openshift:1.5             |
      | redhat-sso-cd-openshift:5.0                |
      | redhat-sso-cd-openshift:6                  |
      | redhat-sso-cd-openshift:6.0                |
      | redhat-sso-cd-openshift:latest             |
      | redhat-sso-cd-openshift:1.0                |
      | redhat-sso72-openshift:1.0                 |
      | redhat-sso72-openshift:1.1                 |
      | redhat-sso72-openshift:1.2                 |
      | redhat-sso72-openshift:1.3                 |
      | redhat-sso72-openshift:1.4                 |
      | redhat-sso73-openshift:1.0                 |
      | redhat-sso73-openshift:latest              |
      | redis:3.2                                  |
      | redis:latest                               |
      | rhdm73-kieserver-openshift:1.0             |
      | ruby:2.2                                   |
      | ruby:2.3                                   |
      | ruby:2.4                                   |
      | ruby:2.5                                   |
      | ruby:latest                                |
      | ruby:2.0                                   |
      | tests:latest                               |
      | wildfly:15.0                               |
      | wildfly:9.0                                |
      | wildfly:16.0                               |
      | wildfly:8.1                                |
      | wildfly:10.0                               |
      | wildfly:10.1                               |
      | wildfly:11.0                               |
      | wildfly:12.0                               |
      | wildfly:13.0                               |
      | wildfly:14.0                               |
      | wildfly:latest                             |

  # @author zhaliu@redhat.com
  Scenario Outline: ImageStream annotation and tag function
    Given I have a project
    And I attempt the registry route based on API url and store it in the :registry_route clipboard
    Given I obtain test data file "image-streams/<file>"
    When I run the :create client command with:
      | f | <file> |
    Then the step should succeed
    When I have a skopeo pod in the project
    Then the step should succeed
    And a pod becomes ready with labels:
      | name=skopeo |
    When I execute on the pod:
      | skopeo                                                      |
      | --insecure-policy                                           |
      | copy                                                        |
      | --dcreds                                                    |
      | <%= user.name %>:<%= user.cached_tokens.first %>            |
      | docker://quay.io/openshifttest/base-alpine:multiarch        |
      | docker://<%= cb.registry_route %>/<%= project.name %>/<tag> |
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
      | case_id   | file             | tag         | isttemplate                                        | istoutput                                                  | isname  | istemplate                                                                               | isoutput                                        |
      | OCP-10090 | annotations.json | testa:prod  | {{range .items}} {{.metadata.annotations}} {{end}} | map\[color:blue\]                                          | testa   | "{{range .spec.tags}} {{.annotations}} {{end}}; {{range .status.tags}} {{.tag}} {{end}}" | map\[color:blue\].*prod\prod.*map\[color:blue\] | # @case_id OCP-10090
      | OCP-10093 | busybox.json     | busybox:2.0 | "{{range .items}} {{.metadata.name}} {{end}}"      | busybox:latest.*busybox:2\.0\|busybox:2\.0.*busybox:latest | busybox | "{{range .status.tags}} {{.tag}} {{end}}"                                                | latest.*2\.0\| 2\.0.*latest                     | # @case_id OCP-10093

