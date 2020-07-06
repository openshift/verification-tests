#!/usr/bin/env ruby


require 'set'

"" "
Search for step usage in all test cases

Arg is file and line number of the step to search for.
We expand the regex and match it recursively against all *.feature files in the current directory.

Output is id(OSE/...) sytanx for querying inactive test cases in Polarion.
" ""


OPT_SYM = '(?: :(\S+))?'
SYM = ':(\S+)'
OPT_QUOTED = '(?: "(.+?)")?'
QUOTED = '"(.+?)"'
HTTP_URL = '(https?:\/\/.+)'
USER = 'the( \\S+)? user'
NUMBER = '([0-9]+|<%=.+?%>)'
WORD = '(\w+|<%=.+?%>)'
OPT_WORD = "(?: #{WORD})?"
# use for regular expression
RE = '/(.+?)/'


def get_regex(line_num, source)
  File.open(source) do |f|
    f.readlines.each_with_index do |line, i|
      if i == line_num
        result = eval("\"" + line + "\"")
        start = result.index("/^") + 2
        # one-off error for some reason
        finish = result.reverse.index("/$") + 3
        pattern = result[start..-finish]
        return pattern
      end
    end
  end
end

if $0 == __FILE__
  source = ARGV[0]
  # Most editors count from 1 so subtract one for comparing with the index
  line_num = ARGV[1].to_i - 1
  pattern = get_regex(line_num, source)

  puts pattern
  step_re = Regexp.new(pattern)
  case_id_re = /@case_id\s+(\S+)/
  features = Dir.glob("./**/*.feature")
  case_features = Hash.new { |h, v| h[v] = Set.new }
  feature_cases = Hash.new { |h, v| h[v] = Set.new }
  features.each do |path|

    match_linenum = []
    File.open(path) do |f|
      lines = f.readlines
      num_lines = lines.length
      lines.each_with_index do |line, i|
        if step_re =~ line
          match_linenum.append(i)
        end
      end
      if match_linenum
        reversed = lines.reverse
        match_linenum.each do |ln|
          offset = num_lines - ln
          reversed[offset..].each_with_index do |line, i|
            if case_id_re =~ line
              b = File.basename(path)
              case_features[$1] << b
              feature_cases[b] << $1
              break
            end
          end
        end
      end
    end
  end
  case_features.each do |k, v|
    puts "#{k}: " + v.to_a.join(" ")
  end
  feature_cases.each do |k, v|
    puts "#{k}: " + v.to_a.join(" ")
  end
  puts "id:(OSE/" + case_features.keys.join(" OSE/") + ")"
end
