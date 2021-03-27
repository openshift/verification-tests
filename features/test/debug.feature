@some_feature_tag
Feature: Debug and Explore Stuff

  @pry
  Scenario: I want to pry
    Given I pry

  @admin_pry
  @admin
  Scenario: I want to pry again
    Given I pry

  @destructive_pry
  @admin
  @destructive
  Scenario: I want to pry again
    Given I pry

  @pry_outline
  Scenario Outline: I want to pry an outline
    When I pry
    Examples: first test case
      | garga|marga |
      |hodi | brodi |
      |mura |    ura|

    @pry_tbl
    Examples: second test case
      |fff|ddd|
      |aaa|b\nbb|

  @pry_table_step
  Scenario: I want to pry in a step with table
    When I pry in a step with table
      | h1 | h2 |
      |va1|va2|
      |vb1|vb \| 2|
      |vc1|v\nc2|
      |vc4|\s\t\\n\\s|
      |gag| <%= "a\na\\na" %> |
      |gor| <%= raise %> |

  @pry_params
  Scenario: I use pry step with parameters
    When I pry with simple param "something"
    And I pry with a param "someotherthing" and a multi-line arg
    """
    Some multil-line string param for testing.
    """
    And I pry with a param "someotherthing" and a multi-line arg
      | some   | header |
      | value1 | value2 |
