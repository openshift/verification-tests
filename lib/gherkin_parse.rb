# frozen_string_literal: true

require 'find'
require 'gherkin/parser'
require 'gherkin/pickles/compiler'
require 'pathname'

require 'bushslicer'

module BushSlicer
  # @note Used to help parse out feature files using Gherkin 3
  class GherkinParse
    include Common::BaseHelper
    COMMENT_OR_TAG = /^\s*(#|@)/
    SCENARIO_DEFINITION = /^\s*(Scenario)/
    EMPTY_STRING = /^\s*$/
    COMMENT = /^\s*\#$/

    private def case_id_re(*ids)
      /^(.*)# @case_id (#{ids.join("|")})$/
    end

    # @param [String] feature the path to a feature file
    # @return [Hash] a gherkin parsed feature
    def parse_feature(feature)
      open(feature) {|io| Gherkin::Parser.new.parse io}
    end

    # @note further parse a feature to compile it into pickles
    # @param [Hash] parsed_feature a previously gherkin parsed object
    # @param [String] feature_path the path to the feature
    # @return [Hash] parsed pickles
    def parse_pickles(feature_path, parsed_feature = nil)
      parsed_feature ||= parse_feature(feature_path)
      Gherkin::Pickles::Compiler.new.compile(parsed_feature, feature_path)
    end

    # @param feature [String, Hash] file path or a parsed feature
    # @return [Array<???>]
    def scenarios_raw(feature)
      case feature
      when String
        feature = parse_feature feature
      when Hash
      else
        raise "unknown feature specification: #{feature.inspect}"
      end

      if feature.has_key? :feature
        # for gherkin 4.0 or greater
        return feature[:feature][:children]
      elsif feature.has_key? :scenarioDefinitions
        return feature[:scenarioDefinitions]
      else
        raise "unknown gherkin parsed format"
      end
    end

    def feature_dirs
      @feature_dirs ||= [
        File.join(HOME, "features"),
        File.join(PRIVATE_DIR, "features")
      ].select {|p| File.directory? p}
    end

    # convert test case ids to [file, line] pairs based on comments e.g.
    #   `# @case_id ABC-123456`
    # @param case_ids [Array<String>] test case IDs
    # @return [Hash<String, Array>] `{ case_id => [file, line] }` mapping
    def locations_for(*case_ids)
      raise "specify test case IDs" if case_ids.empty?
      res = {}
      find_follow(*feature_dirs) do |path|
        next unless path.end_with?(".feature") && File.file?(path)

        id_found = nil
        IO.foreach(path).with_index(1) do |line, index|
          break if !id_found && case_ids.empty? # no more IDs to search for
          if id_found
            # valid scenario or examples table should be located at first
            #   non-comment/tag line
            if line =~ COMMENT_OR_TAG
              # skip this line as it is a comment or cucumber scenario tags
              next
            elsif line =~ /^\s*(Scenario|Examples:)/
              # add to result and continue traversal for remaining IDs
              res[id_found] = [path, index]
              id_found = nil
              next
            else
              raise "invalid line following #{id_found} comment: #{line}"
            end
          else
            id_matcher = line.rstrip.match(case_id_re(*case_ids))
            if id_matcher
              id_found = id_matcher[2]
              pre_tag = id_matcher[1]
              case_ids.delete(id_found)
            end

            if !id_found || pre_tag =~ EMPTY_STRING
              # empty pre_tag means that this is not an example thus we
              # need to figure out the actualy line on a further line
              next
            elsif pre_tag =~ /^\s*\|.+\|\s+$/
              res[id_found] = [path, index]
              id_found = nil
              next
            else
              raise "cannot understand line: #{line}"
            end
          end
        end
      end
      if case_ids.empty?
        return res
      else
        raise "could not find locations for case IDs: #{case_ids.join(?,)}"
      end
    end

    # convert test case ids to [file, range] pairs based on comments e.g.
    #   `# @case_id ABC-123456`
    # @param case_ids [Array<String>] test case IDs
    # @return [Hash<String, Hash>] `{ case_id => {file: [String], range: [Range]} }` mapping
    # @yield [path, lines, ranges] where `path` is a String, `lines` is an
    #   `Array[String]` and `ranges` is a `Hash<String,Range>`
    # @note for scenario outline examples, method returns the whole scenario
    #   outline as a range, we do not split it out
    def ranges_for(*case_ids, dir: nil)
      raise "specify some test case IDs" if case_ids.empty?
      res = {}
      case_id_re = case_id_re(*case_ids)
      if dir
        dirs = [dir]
        relative_to = dir
      else
        dirs = feature_dirs
        relative_to = nil
      end
      find_follow(*dirs) do |path|
        break if case_ids.empty?
        next unless path.end_with?(".feature") && File.file?(path)

        ranges = {}
        lines = IO.readlines(path)
        lines.each_with_index do |line, index|
          id_matcher = line.match(case_id_re)
          if id_matcher
            id_found = id_matcher[2]
            case_ids.delete(id_found)
            lineno = index + 1
            ranges[id_found] = scenario_range(lines, lineno)
            break if case_ids.empty?
            case_id_re = case_id_re(*case_ids)
          end
        end
        unless ranges.empty?
          path_rel = relative_path(path, relative_to)
          res.merge!(ranges.map{|c,r|[c,{file: path_rel, range: r}]}.to_h)
          yield(path_rel, lines, ranges) if block_given?
        end
      end
      if case_ids.empty?
        return res
      else
        raise "could not find locations for case IDs: #{case_ids.join(?,)}"
      end
    end

    # first we find line of next scenario definition, then we go back to find
    #   first non-empty, non-comment and non-tag line
    # @return [Range]
    private def scenario_range(lines, lineno)
      first_index = nil
      last_index = nil
      index = lineno - 1
      next_scenario_line = lines[index..-1].find_index do |line|
        line =~ SCENARIO_DEFINITION
      end
      if next_scenario_line
        next_scenario_line += index
      else
        next_scenario_line = lines.size - 1
        last_scenario = true
      end
      lines_to_next_scenario = (index...next_scenario_line)
      if lines_to_next_scenario.any? &&
          lines[lines_to_next_scenario].all? {|l| l =~ COMMENT_OR_TAG }
        # this means original line was a scenario comment or a cucumber tag or
        #   a scenario definition line
        next_next = lines[next_scenario_line+1..-1].find_index do |line|
          line =~ SCENARIO_DEFINITION
        end
        if next_next
          next_scenario_line += 1 + next_next
        else
          next_scenario_line = lines.size - 1
          last_scenario = true
        end
        lineno_in_scenario_header = true
      else
        lineno_in_scenario_header = false
      end
      # now check back for non-scenario lines
      if last_scenario
        (0..next_scenario_line).reverse_each do |i|
          unless lines[i] =~ EMPTY_STRING
            last_index = i
            break
          end
        end
      else
        (0..next_scenario_line-1).reverse_each do |i|
          unless lines[i] =~ COMMENT_OR_TAG || lines[i] =~ EMPTY_STRING
            last_index = i
            break
          end
        end
      end

      # now go up to find first line
      if lineno_in_scenario_header
        line_in_header = index
      else
        line_in_header = (0..index).reverse_each { |i|
          break(i) if lines[i] =~ SCENARIO_DEFINITION
        }
        if Range === line_in_header
          raise "scenario definition not found for #{lineno}"
        end
      end
      (0..line_in_header-1).reverse_each do |i|
        unless lines[i] =~ COMMENT_OR_TAG
          first_index = i + 1
          break
        end
      end

      return (first_index+1..last_index+1)
    end

    # convert {case_id => [file, line], ...} pairs to Hash like:
    # some_case_id:
    #   file: some/path
    #   scenario: some scenarioname
    #   args:
    #     arg: if any
    def spec_for(hash, root: nil)
      final = {}
      hash.each do |case_id, (file, line)|
        file_rel = relative_path(file, root)
        res = {}
        scenarios_raw(file).each do |scenario|
          if scenario[:scenario][:location][:line] == line
            res["file"] = file_rel
            res["scenario"] = scenario[:scenario][:name]
            res["tags"] = scenario[:scenario][:tags].map{|s| s[:name][1..-1]}
          elsif scenario[:scenario][:keyword] == "Scenario Outline"
            scenario[:scenario][:examples].each do |examples_table|
              if examples_table[:location][:line] == line
                res["file"] = file_rel
                res["scenario"] = scenario[:scenario][:name]
                res["tags"] = scenario[:scenario][:tags].map{|s| s[:name][1..-1]}
                res["tags"].concat examples_table[:tags].map { |ex_tag|
                  ex_tag[:name][1..-1]
                }
                # FYI example[:keyword] == "Examples" but we hardcode
                res["args"] = {"Examples" => examples_table[:name]}
              else
                examples_table[:table_body].each do |example|
                  if example[:location][:line] == line
                    res["file"] = file_rel
                    res["scenario"] = scenario[:scenario][:name]
                    res["tags"] = scenario[:scenario][:tags].map{|s| s[:name][1..-1]}
                    res["tags"].concat examples_table[:tags].map { |ex_tag|
                      ex_tag[:name][1..-1]
                    }

                    header = examples_table[:table_header][:cells].map { |cell|
                      cell[:value]
                    }
                    values = example[:cells].map { |cell| cell[:value] }
                    res["args"] = Hash[header.zip(values)]
                  end
                  break unless res.empty? # break out of examples rows loop
                end
              end
              break unless res.empty? # break out of example tables loop
            end
          end
          break unless res.empty? # break out of scenarios loop
        end
        if res.empty?
          raise "could not find matching scenario for #{case_id}"
        else
          final[case_id] = res
        end
      end
      return final
    end

    private def relative_path(path, root = nil)
      root ||= File.absolute_path("#{__FILE__}/../..")
      root = File.absolute_path(root)
      return Pathname.new(File.absolute_path(path)).relative_path_from(Pathname.new(root)).to_s
    end
  end
end
