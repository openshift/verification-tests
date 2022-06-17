Feature: oc import-image related feature

  # @author chunchen@redhat.com
  # @case_id OCP-11490
  Scenario: [origin_infrastructure_437] Import new tags to image stream
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/templates/tc488870/application-template-stibuild.json |
    Then the step should succeed
    When I run the :new_secret client command with:
      | secret_name     | sec-push                                                             |
      | credential_file | <%= expand_private_path(conf[:services, :docker_hub, :dockercfg]) %> |
    Then the step should succeed
    When I run the :secret_add client command with:
      | sa_name         | builder                     |
      | secret_name     | sec-push                    |
    Then the step should succeed
    Given a 5 character random string is stored into the :tag_name clipboard
    When I run the :new_app client command with:
      | template | python-sample-sti                   |
      | param    | OUTPUT_IMAGE_TAG=<%= cb.tag_name %> |
    When I run the :get client command with:
      | resource        | imagestreams |
    Then the output should contain "python-sample-sti"
    And the output should not contain "<%= cb.tag_name %>"
    Given the "python-sample-build-sti-1" build was created
    And the "python-sample-build-sti-1" build completed
    When I run the :import_image client command with:
      | image_name         | python-sample-sti        |
    Then the step should succeed
    When I run the :get client command with:
      | resource_name   | python-sample-sti |
      | resource        | imagestreams      |
      | o               | yaml              |
    Then the output should contain "tag: <%= cb.tag_name %>"

  # @author chaoyang@redhat.com
  # @case_id OCP-10585
  Scenario: OCP-10585 Do not create tags for ImageStream if image repository does not have tags
    When I have a project
    And I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/is_without_tags.json |
    Then the step should succeed
    When I run the :get client command with:
      | resource      | imagestreams |
    Then the output should contain "hello-world"
    When I run the :get client command with:
      | resource_name   | hello-world  |
      | resource        | imagestreams     |
      | o               | yaml             |
    And the output should not contain "tags"

  # @author wjiang@redhat.com
  # @case_id OCP-10721
  Scenario: OCP-10721 Could not import the tag when reference is true
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510523.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should not contain:
      | aosqeruby:3.3 |
    """

  # @author wsun@redhat.com
  # @case_id OCP-11200
  Scenario: OCP-11200 Import image when pointing to non-existing docker image
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510524.json |
    Then the step should succeed
    Given I wait up to 10 seconds for the steps to pass:
    """
    When I run the :import_image client command with:
      | image_name | tc510524 |
    And the output should match:
      | mport failed |
    """

  # @author wjiang@redhat.com
  # @case_id OCP-11536
  Scenario: OCP-11536 Import image when spec.DockerImageRepository defined without any tags
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510525.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should match:
      | aosqeruby:latest |
    """

  # @author wjiang@redhat.com
  # @case_id OCP-11760
  Scenario: OCP-11760 Import Image when spec.DockerImageRepository not defined
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510526.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should contain:
      | aosqeruby:3.3 |
    And the output should not contain:
      | aosqeruby:latest |
    """

  # @author wjiang@redhat.com
  # @case_id OCP-11931
  Scenario: OCP-11931 Import image when spec.DockerImageRepository with some tags defined when Kind!=DockerImage
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510525.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should contain:
      | aosqeruby:latest |
    """
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510527.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should contain:
      | aosqeruby33:3.3 |
    And the output should contain 2 times:
      | aosqe/ruby-20-centos7@sha256:093405d5f541b8526a008f4a249f9bb8583a3cffd1d8e301c205228d1260150a |
    """

  # @author wjiang@redhat.com
  # @case_id OCP-12052
  @smoke
  Scenario: OCP-12052 Import image when spec.DockerImageRepository with some tags defined when Kind==DockerImage
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510528.json |
    Then the step should succeed
    Given I wait up to 15 seconds for the steps to pass:
    """
    When I run the :get client command with:
      | resource | imagestreamtags |
    Then the step should succeed
    And the output should contain:
      | aosqeruby:3.3 |
    """

  # @author wsun@redhat.com
  # @case_id OCP-12147
  Scenario: OCP-12147 Import Image without tags and spec.DockerImageRepository set
    Given I have a project
    When I run the :create client command with:
      | filename | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/tc510529.json |
    Then the step should succeed
    When I run the :import_image client command with:
      | image_name | tc510529 |
    Then the step should fail
    And the output should match:
      | error:.*image stream |

  # @author xiaocwan@redhat.com
  # @case_id OCP-11089
  Scenario: OCP-11089 Tags should be added to ImageStream if image repository is from an external docker registry
    Given I have a project
    When I run the :create client command with:
      | f | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/image-streams/external.json |
    Then the step should succeed
    And I wait for the steps to pass:
    ## istag will not show promtly as soon as is create, need wait for a few seconds
    """
    When I run the :get client command with:
      | resource | imageStreams |
      | o        | yaml         |
    Then the step should succeed
    And the output should match:
      | tag:\\s+None    |
      | tag:\\s+latest  |
      | tag:\\s+busybox |
    """

  # @author geliu@redhat.com
  # @case_id OCP-12765
  Scenario: OCP-12765 Allow imagestream request deployment config triggers by different mode('TagreferencePolicy':source/local)
    Given I have a project
    When I run the :tag client command with:
      | source_type | docker                                          |
      | source      | quay.io/openshifttest/deployment-example:latest |
      | dest        | deployment-example:latest                       |
    Then the output should match:
      | [Tt]ag deployment-example:latest           |
    When I run the :new_app client command with:
      | image_stream | deployment-example:latest   |
    Then the output should match:
      | .*[Ss]uccess.*|
    When I run the :get client command with:
      | resource        | imagestreams |
    Then the output should match:
      | .*deployment-example.* |
    When I run the :get client command with:
      | resource_name   | deployment-example |
      | resource        | dc                 |
      | o               | yaml               |
    Then the output should match:
      |[Ll]astTriggeredImage.*deployment-example@sha256.*|
    When I run the :delete client command with:
      | object_type | dc |
      | all         |    |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | is |
      | all         |    |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | svc |
      | all         |     |
    Then the step should succeed
    When I run the :tag client command with:
      | source_type      | docker                                          |
      | source           | quay.io/openshifttest/deployment-example:latest |
      | dest             | deployment-example:latest                       |
      | reference_policy | local                                           |
    Then the output should match:
      | [Tt]ag deployment-example:latest           |
    When I run the :new_app client command with:
      | image_stream | deployment-example:latest   |
    Then the output should match:
      | .*[Ss]uccess.* |
    When I run the :get client command with:
      | resource        | imagestreams |
    Then the output should match:
      | .*deployment-example.* |
    When I run the :get client command with:
      | resource_name   | deployment-example |
      | resource        | dc                 |
      | o               | yaml               |
    Then the output should match:
      | [Ll]astTriggeredImage.*:.*<%= project.name %>\/deployment-example@sha256.*|

  # @author geliu@redhat.com
  # @case_id OCP-12766
  Scenario: OCP-12766 Allow imagestream request build config triggers by different mode('TagreferencePolicy':source/local)
    Given I have a project
    When I run the :import_image client command with:
      | from       | quay.io/openshifttest/ruby-25-centos7 |
      | confirm    | true                                  |
      | image_name | ruby-25-centos7:latest                |
    Then the step should succeed
    When I run the :new_build client command with:
      | image_stream | ruby-25-centos7                       |
      | code         | https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    When I run the :get client command with:
      | resource_name   | ruby-ex |
      | resource        | bc      |
      | o               | yaml    |
    Then the expression should be true> @result[:parsed]['spec']['triggers'][3]['imageChange']['lastTriggeredImageID'].include? 'centos/ruby-25-centos7'
    When I run the :delete client command with:
      | object_type | bc |
      | all         |    |
    Then the step should succeed
    When I run the :delete client command with:
      | object_type | is |
      | all         |    |
    Then the step should succeed
    When I run the :import_image client command with:
      | from            | quay.io/openshifttest/ruby-25-centos7 |
      | confirm         | true                                  |
      | image_name      | ruby-25-centos7:latest                |
      | reference-policy| local                                 |
    Then the step should succeed
    When I run the :new_build client command with:
      | image_stream | ruby-25-centos7                       |
      | code         | https://github.com/sclorg/ruby-ex.git |
    Then the step should succeed
    When I run the :get client command with:
      | resource_name   | ruby-ex |
      | resource        | bc      |
      | o               | yaml    |
    Then the expression should be true> @result[:parsed]['spec']['triggers'][3]['imageChange']['lastTriggeredImageID'].include? '<%= project.name %>/ruby-25-centos7'

