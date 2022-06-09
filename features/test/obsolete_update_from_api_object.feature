Feature: test refactor of update_from_api_object to use raw_resource

  Scenario: test image_stream_tag
    Given I have a project
    And I run the :tag client command with:
      | source_type | docker                                        |
      | source      | quay.io/openshifttest/pushwithdocker19:latest |
      | dest        | pushwithdocker19:latest                       |
    Then the step should succeed
    And the "pushwithdocker19:latest" image stream tag was created
    And evaluation of `image_stream_tag("pushwithdocker19:latest").digest` is stored in the :a clipboard
    And evaluation of `image_stream_tag.docker_version` is stored in the :b clipboard
    And evaluation of `image_stream_tag.annotations` is stored in the :c clipboard
    And evaluation of `image_stream_tag.labels` is stored in the :d clipboard
    And evaluation of `image_stream_tag.config_user` is stored in the :e clipboard
    And evaluation of `image_stream_tag.config_env` is stored in the :f clipboard
    And evaluation of `image_stream_tag.config_cmd` is stored in the :g clipboard
    And evaluation of `image_stream_tag.workingdir` is stored in the :h clipboard
    And evaluation of `image_stream_tag.exposed_ports` is stored in the :i clipboard
    And evaluation of `image_stream_tag.image_layers` is stored in the :j clipboard
