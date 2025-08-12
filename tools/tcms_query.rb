#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")

"""
Utility to query a TCMS run much like the Chrome extension

use -i to specify the testrun id
use -f to filter the output for only a specific user@redhat.com
use -e to exclude displaying those that have ruby scripts and have 'AUTO' labeled already
use -a to query for ruby testcases that have 'Script' filed with 'ruby' and is CONFIRMED
use --help to see usage information

Examples:
$ ./query_tcms.rb -i 130186 -f pruan@redhat.com
 - will filter out the results only with author pruan@redhat.com
 - if you leave out the -f portion it will return all caseruns
"""
require 'tcms/tcms'
require 'text-table'
require 'optparse'
require 'json'
require 'io/console' # for reading password without echo
require 'time'
require 'gherkin_parse'
require 'oga'  # replaces nokogiri
require 'open-uri'

require 'collections'
require 'jira_rht'

def print_report(options)
  testrun_id = options.testrun_id
  author_filter = options.author if options.author
  outcome_filter = options.outcome if options.outcome
  tcms =  options.tcms
  res  = tcms.get_run_cases(testrun_id)
  table = Text::Table.new
  table.head = ['caserun_id', 'case_id', 'summary', 'status', 'notes']
  regex = /(automated)? by\s(\w+)?/
  cases = []
  res.each do |caserun|
    auto_by = caserun['notes'].match(regex)[2] if caserun['notes'].match(regex)
    row = [caserun['case_run_id'], caserun['case_id'], caserun['summary'].strip[0..50], caserun['case_run_status'], auto_by]
    next if author_filter && author_filter != auto_by
    next if outcome_filter && outcome_filter != caserun['case_run_status']
    table.rows << row
  end
  puts table
  puts "Total: #{table.rows.count}\n"
  if options.create_run
    table.rows.each do |row|
      cases.push(row[1])
    end
  end
  return cases
end

# helper method to get the author from the 'Notes' field of a testcase
def get_author_from_notes(tc_notes)
  author_regex1 = /(automated by)\s(\w+)?/i
  author_regex2= /(\w+)(?: is)? automat(\w+)/
  auto_by = tc_notes.match(author_regex1)[2] if tc_notes.match(author_regex1)
  # try another regex format
  if auto_by.nil?
    auto_by = tc_notes.match(author_regex2)[1] if tc_notes.match(author_regex2)
  end
  auto_by = "unknown" if auto_by.nil?
  return auto_by
end

def report_auto_testcases_by_author(options)
  tcms = options.tcms
  table = Text::Table.new
  table.head = ['case_id', 'summary', 'author']
  script_pattern = "\"ruby\""
  unknown_cases = []   # array to story 'unknown' testcase ids
  authors = {}
  auto_case_total = 0
  res = tcms.filter_cases()
  total_cases = res.count
  res.each do | testcase|
    # we only care about script field that's not empty (meaning it's automated)
    if testcase['script'] && !testcase['script'].empty?
      if testcase['is_automated'] == 0
        puts "has script but not marked automated: #{testcase['case_id']}"
      end

      if (testcase['script'].include? script_pattern and testcase['case_status'] == 'CONFIRMED')
        auto_case_total += 1
        auto_by = get_author_from_notes(testcase['notes'])
        if auto_by == 'unknown'
          unknown_cases << testcase['case_id']
        end
        if authors.keys().include? auto_by
          authors[auto_by] += 1
        else
          authors[auto_by] = 1
        end

        #authors.push(auto_by) unless authors.include? auto_by
        if options.by_author
          if auto_by ==  options.author
            table.rows << [testcase['case_id'], testcase['summary'].strip[0..20], auto_by]
          end
        end
      end
    else
      if testcase['is_automated'] != 0
        puts "has no script but marked automated: #{testcase['case_id']}"
      end
    end
  end
  print "Cases with Unknown authors #{unknown_cases}\n"
  print table
  table_sum = Text::Table.new
  table_sum.head = ['author', 'testcases']
  authors.sort.to_h.each do |a, c|
    table_sum.rows << [a, c]
  end
  print table_sum
  print "Automated a total of #{auto_case_total} out of #{total_cases} possible testcases for a ratio of #{(auto_case_total.to_f/total_cases * 100).round(2)}%"
end


##  query testplan and return all testcases with script field that has
#   "auto" and 'ruby' in the script section
def report_auto_testcases(options)
  tcms = options.tcms
  table = Text::Table.new
  table.head = ['case_id', 'summary', 'ruby script', 'auto_by']
  script_pattern = "\"ruby\""
  cases = []
  res = tcms.filter_cases()
  total_cases = res.count
  ruby_scripts_count = 0
  ruby_cases = []
  need_update = 0
  regex = /(automated)? by\s(\w+)?/
  res.each do | testcase |
    if not testcase['script'].nil?
      if (testcase['script'].include? script_pattern and testcase['case_status'] == 'CONFIRMED')
        ruby_scripts_count += 1
        begin
          script = JSON.parse(testcase['script'])
        rescue Exception => e
          print "Error parsing testcase #{testcase["case_id"]} entry in TCMS, please check for formatting" + "\n" + e.message
        end

        auto_by = testcase['notes'].match(regex)[2] if testcase['notes'].match(regex)
        if options.exclude_auto
          if testcase['is_automated'] == 0
            need_update += 1
            table.rows << [testcase['case_id'], testcase['summary'].strip[0..20],
                           script['ruby'].strip[0..40], auto_by] #testcase['is_automated']]
          end
        else
          raise "bad case #{testcase['case_id']}" unless script.kind_of?(Hash)
          table.rows << [testcase['case_id'], testcase['summary'].strip[0..20],
                         script['ruby'].strip[0..40], auto_by] #testcase['is_automated']]

        end
        ruby_cases.push(testcase['case_id'])
        if script['ruby'].starts_with? 'features/'
          if options.correct_script
            # udpate the script
            script['ruby'] = script['ruby'][9..-1]
            tcms.update_testcases(testcase['case_id'], {"script"=> script})
          else
            print "#{testcase['case_id']} has malform script field\n"
          end
        end
      end
    end
  end
  puts table
  table.rows.each do |row|
    cases.push(row[0])
  end

  puts "Total: #{ruby_scripts_count} out of possible #{total_cases}, need_update: #{need_update}"

  return cases
end

# reads in a query file which is a yaml file containning parameters that a user wants to query on

def report_query_result(options)
  tcms = options.tcms
  table = Text::Table.new
  table.head = ['case_id', 'summary', 'ruby script', 'auto_by']

  query_file = options.query
  params = YAML.safe_load_file(query_file, aliases: true, permitted_classes: [Symbol, Regexp])
  params_hash = BushSlicer::Collections.hash_symkeys(params['filters'])

  # translate tag names into ids
  if params_hash[:tag__in]
    tag_names = [params_hash[:tag__in]].flatten
    tag_ids = tag_names.map { |n| tcms.get_tag_id(n).to_s}
    params_hash[:tag__in] = tag_ids
  end
  res = tcms.filter_cases(params_hash)
  script_pattern = "\"ruby\""
  regex = /(automated)? by\s(\w+)?/
  cases = []
  res.each do | testcase |
    if not testcase['script'].nil?
      if (testcase['script'].include? script_pattern and testcase['case_status'] == 'CONFIRMED')
        begin
          script = JSON.parse(testcase['script'])
        rescue Exception => e
          print "Error parsing testcase #{testcase["case_id"]} entry in TCMS, please check for formatting" + "\n" + e.message
        end

        auto_by = testcase['notes'].match(regex)[2] if testcase['notes'].match(regex)
        table.rows << [testcase['case_id'], testcase['summary'].strip[0..20],
                           script['ruby'].strip[0..40], auto_by]
      else
        table.rows << [testcase['case_id'], testcase['summary'].strip[0..70], testcase['script'], auto_by]
      end
    else
      # not automated
      table.rows << [testcase['case_id'], testcase['summary'].strip[0..70], testcase['script'], ' ']
    end
  end
  puts table
  table.rows.each do |row|
    cases.push(row[0])
  end
  print "A total of #{res.count} cases matched the filter #{params_hash}"
end

def update_notes(options)
  if options.cases.nil?
    puts "You need to specify at least one testcase id"
    return
  end
  time_stamp = "#{Time.now().strftime("%Y-%m-%d")}"
  notes =  options.notes + " " + time_stamp
  cases = options.cases.split(',')
  tcms  = options.tcms
  tcms.update_testcases(cases, {"notes" => notes})
end

def get_bushslicer_home
  ENV['BUSHSLICER_HOME'] || File.dirname(File.dirname(__FILE__))
end

def sync_tags(tcms)
  # we only sync specific scenario tags, not everything
  if tcms.default_opts[:plan] == 4962
    # V2 tags
    valid_tags_to_be_added = ['devenv', 'destructive', 'aggressive', 'sequential']
  else  # everything else is assumed to be v3 variants
    valid_tags_to_be_added = ['admin', 'destructive', 'vpn', 'smoke']
  end
end

# Search for scenario tags of a scenario
def get_scenario_tags(scenario, tcms)
  #Remove the leading '@' from tags
  scenario_tags = scenario[:tags].map{|s| s[:name][1..-1]}

  #Compare valid tags and scenario tags, and return the common tags.
  verified_tags = sync_tags(tcms)
  matching_tags = (scenario_tags & verified_tags)
end

# Search for the Example table tags of a scenario
def get_example_table_tags(example, tcms)
  #Remove the leading '@' from tags
  example_table_tags = example[:tags].map{|ex_tag| ex_tag[:name][1..-1]}

  if example_table_tags.empty?
    return example_table_tags
  else
    #Compare valid tags and scenario tags, and return the common tags.
    verified_table_tags = sync_tags(tcms)
    matching_table_tags = (example_table_tags & verified_table_tags)
  end
end

# generic update script field of TCMS case
# usage example:
# Scenario
# tcms_query.rb -c 295234 -s "features/rest/add_app.feature:78"
# Scenario Outline
# tcms_query.rb -c 259977 -s "features/rest/add_app.feature:41"
def update_script(options)
  tcms  = options.tcms
  path, line_number = options.script.split(':')
  raise "A line number must be specified" unless line_number
  target_line_number = line_number.to_i
  scenario_description = nil
  example_row_headers = []
  example_row_cells = []
  example_table_tags= []
  arg_hash = {}
  tcms_arg_field = nil
  polarion_arg_field = nil
  tags = []

  gparser = BushSlicer::GherkinParse.new
  file_contents = gparser.parse_feature(File.join(get_bushslicer_home, path))
  #Iterate over each scenario in a file
  # XXX for gherkin 4.0  or greater, the hash structures have changed and not
  # backward compatible
  # https://github.com/cucumber/gherkin/blob/master/CHANGELOG.md
  if file_contents.has_key? :feature
    # for gherkin 4.0 or greater
    scenarios = file_contents[:feature][:children]
  else
    scenarios = file_contents[:scenarioDefinitions]
  end

  scenarios.each do |scenario|
    # need to clear out arg_hash each iteration.
    arg_hash = {}
    #Check for the Scenario description. If a basic scenario, take the description.
    #If a Scenario Outline, determine if it's a table argument, or just the Scenario Outline name.
    if scenario[:location][:line] == target_line_number
      scenario_description = scenario[:name]
      tags = get_scenario_tags(scenario, tcms)
      #exit once the scenario description is found
      break
    #The following block is if a table argument is specified after -s
    elsif scenario[:type] == :ScenarioOutline
      scenario[:examples].each do |example|
        if example[:location][:line] == target_line_number
          # Get the scenario description
          scenario_description = scenario[:name]
          # Get the example description
          example_description = example[:name]
          # FYI example[:keyword] == "Examples" but we hardcode
          arg_hash["Examples"] = example_description
        else
          example[:tableBody].each do |row|
            if row[:location][:line] == target_line_number
              #Get the scenario description
              scenario_description = scenario[:name]
              #Get the scenario tags
              tags = get_scenario_tags(scenario, tcms)
              #Get the example table tags, if any
              example_table_tags = get_example_table_tags(example, tcms)
              #Get table headers to zip with arguments
              example[:tableHeader][:cells].each do |thead|
                example_row_headers << thead[:value]
              end
              #Get table arguments
              row[:cells].each do |cell|
                example_row_cells << cell[:value]
              end
            end
          end
          #Zip the table headers and table cells
          example_row_headers.each_with_index do |value, index|
            arg_hash[value] = example_row_cells[index]
          end
        end
      end
      if arg_hash.empty?
        arg_hash = nil
      else
        tcms_arg_field = arg_hash.to_json
        polarion_arg_field = arg_hash
      end
    end
  end
  if scenario_description == nil
    raise 'Can not find Scenario, Scenario Outline or Examples Table target line, please check the line number specified for the file is correct'
  end
  # for tcms we need to strip out the features/ part of the arguement
  path = path[9..path.length]
  ruby_script = "#{path}:#{scenario_description}"
  tcms_script_field =  {"ruby"=>ruby_script}.to_json

  #Combine example tags and scenario tags, if any
  tags = tags | example_table_tags

  #Delete existing TCMS tags, replace them with scenario tags
  begin
    tcms.remove_testcase_tags(options.cases, sync_tags(tcms))
  rescue
    raise "Unable to delete old TCMS tags."
  end
  tcms.add_testcase_tags(options.cases, tags) unless tags.empty?

  if options.notes
    time_stamp = "#{Time.now().strftime("%Y-%m-%d")}"
    notes =  options.notes + " " + time_stamp
    tcms.update_testcases(options.cases, {"script"=>tcms_script_field, "arguments"=>tcms_arg_field, "is_automated"=>1, "notes"=> notes})
  else
    tcms.update_testcases(options.cases, {"script"=>tcms_script_field, "is_automated"=>1, "arguments"=>tcms_arg_field})
  end

  print("\nPolarion Auxilliary Data:\n\n")
  polarion_hash = {"cucushift" => {"file" => "#{ruby_script.split(":")[0]}", "scenario" => "#{ruby_script.split(":")[1]}", "args" => polarion_arg_field }}
  # The line_width option removes the 80 char restriction imposed by the yaml gem
  # without this option, to_yaml will split long lines into newlines after 80 chars
  print(polarion_hash.to_yaml(options = {:line_width => -1}) + "\n")
end

  # @testcases is an array of failed testcase in a TCMS hash format.  Use
  # this method to create an issue that is targeted for jenkins run failure
  #
  # We create an issued for a user based on the testrun id.  Create an issue
  # if there is no existing issued around that testrun id (need to query
  # JIRA).  If there's an JIRA already, we just append the new infromation
  # to the 'comments' section of the existing JIRA.  This way we minimize
  # the amount of JIRA issued to the user.
  #
  def create_failed_testcases_issue(testcases, tcms, jira)
    query_params = {
      :assignee => testcases[0]['auto_by'],
      :run_id => testcases[0]['run_id']}
    # read in the config from the :tcms section
    tcms_base_url = tcms.default_opts[:tcms_base_url]
    logger = jira.logger
    options = jira.client.options
    default_issue_type = jira.get_default_issuetype
    issues = jira.find_issue_by_testrun_id(query_params)
    error_logs = ""
    testcases.each do | tc |
      tc_url = tcms_base_url + "case/#{tc['case_id']}"
      bugs_link = " "
      if tc[:bugs]
        tc[:bugs].each do |bug_id|
          bug_url = "https://bugzilla.redhat.com/show_bug.cgi?id=#{bug_id}"
          bugs_link += jira.make_link(bug_url, "bz"+ bug_id + " ")
        end
      end
      error_logs += jira.make_link(tc_url, tc['case_id']) + " " + jira.make_link(tc[:log_url], 'run_log') + " " + bugs_link + "\n"
    end

    if issues.count > 0
      # issue already exist, just append the run logs as comments
      issue = issues[0]
      issue.fetch('reload')  # this is needed to reload all comments
      logger.info("JIRA issue '#{issue.key}' already exists, adding logs to comments section...")

      comment = issue.comments.build
      comment.save!(:body => error_logs)
    else
      # step 1. get the author's information
      assignee = jira.get_user(query_params[:assignee])
      # make sure assignee is still active.
      unless assignee.attrs['active']
        new_assignee = testcases[0]['default_tester']
        logger.info("JIRA user #{assignee.name} is not active, assigning it to default_tester '#{new_assignee}'")
        assignee = jira.get_user(new_assignee)
      end
      if assignee.nil?
        # assign the case to 'default_tester' if automation author is unknown
        reporter = testcases[0]['default_tester']
        logger.info("JIRA system does not have username '#{query_params[:assignee]}', assigning issue to the reporter '#{reporter}'")
        assignee = jira.get_user(reporter)
      end
      components = jira.get_default_components
      component_attrs = components.map { |c| c.attrs }
      default_issue_type = jira.get_default_issuetype
      run_url = jira.make_link(url=(tcms_base_url + "run/#{query_params[:run_id]}"), text=query_params[:run_id])
      error_logs = "Errors from test run #{run_url}" + "\n" + error_logs
      issue_params = {
        "summary" => "test failures from run:#{query_params[:run_id]}",
        "project" => {"id"=> jira.project.id.to_i},
        "issuetype"=>{"id"=> default_issue_type.attrs["id"]},
        "assignee" => assignee.attrs,
        "description" => error_logs,
        "components" => component_attrs #, [component_auto.attrs]
      }
      new_issue = jira.create_issue(fields: issue_params)
      logger.info("Created issue #{new_issue.key} for '#{assignee.name}'") unless new_issue.has_errors?
    end
  end

# query tcms and extract all of the failed logs from a test run
def report_logs(options, status='FAILED')
  tcms = options.tcms
  jira = options.jira
  cases = tcms.get_run_cases(options[:testrun_id])
  filtered_cases = {}
  table = Text::Table.new
  table.head = ['caserun_id', 'case_id', 'auto_by', 'bug_id', 'msg', 'log_url']
  cases.each do | tc |
    tc['auto_by'] = get_author_from_notes(tc['notes'])
    auto_by = tc['auto_by']
    if tc['case_run_status'] == status
      filtered_cases[auto_by] = [] if filtered_cases[auto_by].nil?
      filtered_cases[auto_by] << tc
    end
  end
  testrun_bugs = tcms.get_testrun_bugs(options[:testrun_id])
  bugs_hash = {}
  testrun_bugs.each do |testrun|
    bugs_hash[testrun['case_run_id']] = testrun["bug_id"].to_i
  end

  caserun_list = bugs_hash.keys()

  filtered_cases.sort.each do | author, testcases |
    testcases.each do | tc |
      log_url = nil
      log_url = tcms.get_latest_log_url(tc["case_run_id"]) if options.author == tc['auto_by'] or options.author.nil?
      tc[:bugs] = bugs_hash[tc["case_run_id"]] if caserun_list.include? tc["case_run_id"]
      tc[:log_url] = log_url
      if log_url.nil?
        tc[:error_msg] = nil
      else
        #log_page = Nokogiri::HTML(open(log_url)) unless log_url.nil?
        log_page = Oga.parse_html(open(log_url)) unless log_url.nil?
        back_trace_div = log_page.css('div.step_backtrace')
        if back_trace_div
          # we just take the first line of the backtrace and diplay it.
          # tc[:error_msg] = back_trace_div.children[0]
          tc[:error_msg] = back_trace_div[0].children[0].text
        else
          tc[:error_msg] = "Can't find a error message"
        end
      end
      tc[:testrun_id] = options[:testrun_id]
      table.rows << [tc["case_run_id"], tc["case_id"], tc["auto_by"], tc[:bugs], tc[:error_msg] ,log_url] unless log_url.nil?
    end
    if options.create_jira
      if options.author
        if author == options.author
          create_failed_testcases_issue(testcases, tcms, jira)
        else
          print ("Skipping JIRA update because author '#{author}' did not match author filter '#{options.author}'\n")
        end
      else
        create_failed_testcases_issue(testcases, tcms, jira)
      end
    end
  end
  puts table
end

def create_tcms_run(options)
  cases = options.cases.split(',').map { |c| c.strip }
  tcms = options[:tcms]
  opt = {}
  opt['summary'] = "Test run created by tcms_query."
  opt['case'] = cases
  opt['default_tester'] = tcms.whoami['id']
  res = tcms.create_run(opt)
  print "TCMS run created #{tcms.default_opts[:tcms_base_url]}run/#{res['run_id']}\n"
end

if __FILE__ == $0
  options = OpenStruct.new

  OptionParser.new do |opts|
    opts.banner = "Usage: bin/query_tcms.rb [options]"
    opts.separator("Options")
    opts.on('--ping', "exit with error if tcms cannot be reached") do
      options.ping=true
    end
    opts.on('-a', '--autocases', "query for all cases that has 'Script' entry and have 'ruby' as key") do
      options.get_auto=true
    end
    opts.on('-x', '--correct_script', "Correct testcases with incorrectly features/ included") do
      options.correct_script=true
    end
    opts.on('-b', '--by_author', "query for all cases that has is CONFIRMED, and report it by author name") do
      options.by_author=true
    end
    opts.on('-o', '--outcome [testcase run outcome]', String, "the output to filter by per status_lookup table") do |outcome|
      options.outcome = outcome
    end
    opts.on('-m', '--non_auto', "exclude displaying those that have ruby scripts and marked as AUTO already") do
      options.exclude_auto=true
    end
    opts.on('-j', '--create_jira', "create JIRA issue for user from failed testcases in a TCMS run") do
      options.create_jira=true
    end
    opts.on('-i', '--testrun [testrun_id]', Integer, "The id of the test run") do |id|
      options.testrun_id = id
    end
    opts.on('-e', '--email_filter <auto_by_author_email>', String, "The email of the automation writer") do |author|
      options.author = author
    end
    # this option is used mainly to update the Notes: field in TCMS
    opts.on('-n', '--notes <text_to_be_placed_in_notes>', String, "Notes you want to enter into the testcase") do |notes|
      options.notes = notes
      options.update_tcms = true
    end
    opts.on('-s', '--script <script_and_line_number>', String, "") do | script|
      options.script = script
      options.update_tcms = true
    end
    opts.on('-c', '--cases <csv of case_ids to be update>', String, "csv of testcase ids that you wish to update") do |cases|
      options.cases = cases
    end
    opts.on('-p', '--plan_id [testplan_id]', Integer, "The id of the test plan, default (v3:14587 v2:4962) plan id will be used if none is given") do |id|
      options.plan = id
    end
    opts.on('-f', '--filter [filter_yaml_file]', String, "query TCMS server with the following query file, see doc/examples/query_filter_example.yaml for an example") do |query|
      options.query = query
    end
    opts.on('-l', '--log [FAILED|PASSED]', String, "get the passed/failed logs URL") do |log_type|
      options.log_type = log_type
    end
    opts.on('-r', '--create_tcms_run', "create an new tcms run entry in conjunction with the cases specified by -c") do
      options.create_run=true
    end
  end.parse!
  tcms = BushSlicer::TCMS.new(options.to_h)
  options.tcms = tcms
  if options.create_jira
    jira = BushSlicer::Jira.new(options.to_h)
    options.jira = jira
  end
  cases = []
  if options.get_auto
    cases = report_auto_testcases(options)
  elsif options.query
    report_query_result(options)
  elsif options.ping
    puts tcms.version.to_s
    exit 0
  elsif options.update_tcms
    update_notes(options) if options.notes
    update_script(options) if options.script
  elsif options.by_author
    report_auto_testcases_by_author(options)
  elsif options.log_type
    report_logs(options, options.log_type)
  elsif options.create_run
    raise "You must give a csv list of testcases to be added to the new TCMS run you are creating" unless options.cases
    create_tcms_run(options)
  else
    cases = print_report(options)
  end
end
