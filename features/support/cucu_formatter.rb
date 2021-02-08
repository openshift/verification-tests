#!/usr/bin/env ruby
lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..','lib'))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end

require 'pathname'
require 'cucumber'
require 'base64'
require 'fileutils'
require 'uri'
require 'cgi' # to escape html content
require 'tmpdir' # Dir.tmpdir
require 'zlib'

require 'common' # mainly localhost is used

module BushSlicer
  # custom Cucumber HTML formatter that also cooperates with test case manager
  # TODO: new API https://github.com/cucumber/cucumber-ruby/pull/851/files/
class CucuFormatter
  include Common::Helper

  def initialize(runtime, io_or_path, options)
    if io_or_path.kind_of? String
      ## find place for our formatter log
      if ENV['WORKSPACE'] && File.directory?(ENV['WORKSPACE'])
        # in jenkins it would be nice to have formatter log in WORKSPACE
        @io = File.new(File.join(ENV['WORKSPACE'], "/formatter.log") ,'w')
      else
        @io = File.new("#{Dir.tmpdir}/formatter_#{EXECUTOR_NAME}.log", 'w')
      end

      ## where to store scenario log and artifacts
      if io_or_path == ":auto"
        @log_dir = File.expand_path(localhost.workdir(absolute: true) + "_cucu_formatter")
      else
        @log_dir = File.expand_path(io_or_path)
      end
    else
      # looks like they gave us stdout, that's a mistake
      # @io = io_or_path
      raise "CucuFormatter needs output dir specified"
    end

    prepare_log_dir
    @options = options

    @step_messages = []

    # Read html template
    @template = File.read File.expand_path(File.join(File.dirname(__FILE__), 'formatter_template.html'))

    # register with the Manager
    manager.custom_formatters << self
  end

  # make sure log dir exists and is empty
  def prepare_log_dir
    wipe_log_dir
    # FileUtils.mkdir_p(@log_dir) # subdirs should be created on demand
  end

  def wipe_log_dir
    localhost.delete(@log_dir, :r => true, :raw => true)
  end

  def logger
    raise "not sure it's safe to use logger from a formatter, lets disable for the time being"
  end

  ###################### FORMATTER HOOKS BEGIN ########################

  # cucumber formatter hooks
  def feature_name(keyword, name)
    # Create a new feature hash
    @feature = {:name => name,
                :keyword => keyword}
  end

  def after_features(features)
    # before we handled last scenario log here, now we process log at better
    #   time by calling it from TestCaseManagerFilter
    # process_scenario_log
    # wipe_log_dir # avoid interfering with uploaders; posible harm negligible
  end

  def scenario_name(keyword, name, file_colon_line, source_indent)
    # Create a new scenario hash
    if keyword == 'Scenario Outline'
      @scenario_outline_name = name
      @scenario_keyword = 'Scenario Outline'
    else
      @scenario_keyword = 'Scenario'
      # before we handled previous scenario log here, now we process log at
      #   better time by calling it from TestCaseManagerFilter
      #process_scenario_log
    end
      # Create a new scenario
      @scenario = { :name => @scenario_outline_name ? @scenario_outline_name : name,
                    :status => :failed,
                    :steps => [],
                    :arg => @scenario_outline_name ? name : nil,
                    :file_colon_line => file_colon_line,
                    :before => [],
                    :after => []
                  }
  end

  def before_steps(steps)
    @scenario[:before] = @step_messages.clone
    @step_messages.clear
  end

  def after_feature_element(feature_element)
    @scenario[:after] = @step_messages.clone
    @step_messages.clear
  end

  def after_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background, file_colon_line)
    unless @scenario_keyword == 'Scenario Outline'
      step = {:name => self.gen_step_name(keyword, step_match, status, step_match.file_colon_line, source_indent),
              :status => status,
              :messages => @step_messages.clone}
      @step_messages.clear
      step[:multiline_arg] = multiline_arg if multiline_arg
      if exception
        step[:backtrace] = gen_repo_links_in_backtrace(exception.backtrace)
        step[:backtrace].unshift(exception.class.to_s)
        step[:backtrace].unshift(CGI.escapeHTML(exception.to_s))
      end
      @scenario[:steps].push(step)
    end
  end

  def before_outline_table(outline_table)
    @outline_table = outline_table
  end

  def after_outline_table(outline_table)
    @outline_table = nil
    @scenario_outline_name = nil
  end

  def puts(message)
    @step_messages.push(message.to_s)
  end

  def embed(src, mime_type, label)
    # official html embedding:
    # https://github.com/cucumber/cucumber-ruby/blob/master/lib/cucumber/formatter/html.rb
    # some discussion about current official HTML formatter behavior
    # https://github.com/cucumber/cucumber-ruby/issues/775
    # Namely we may want to create attachments in `html_report` dor to work fine
    #   with the official HTML formatter and then attach this as external file
    #   regardless if `src` is a file path or data.

    label = CGI.escapeHTML(label)

    if (File.file?(src) rescue false)
      FileUtils.cp src scenario_artifacts_dir
      basename = CGI.escapeHTML(File.basename(src))
      link = %[<a href="#{basename}">#{label}</a>]
    elsif src =~ /\Adata:image\/(png|gif|jpg|jpeg);base64,[A-Za-z0-9+\/]+=*\z/
      ## image Data URI
      link = %[<img src="#{src}" alt="#{label}"/>}]
    elsif src =~ /\Adata:[-a-zA-Z0-9_]+\/[-a-zA-Z0-9_+.;=]+;base64,[A-Za-z0-9+\/]+=*\z/
      ## random type Data URI
      link = %[<a href="#{src}">#{label}</a>]
    elsif mime_type =~ /\Aimage\/(png|gif|jpg|jpeg)\z/
      ## raw image data
      link = %[<img src="data:#{mime_type};base64,#{Base64.strict_encode64 src}" alt="#{label}"/>}]
    elsif mime_type =~ /\A[-a-zA-Z0-9_]+\/[-a-zA-Z0-9_+.;=]+;base64\z/ &&
          src =~ /\A[A-Za-z0-9+\/]+=*\z/
      ## Base64 encoded raw data
      if mime_type =~ /\Aimage\/(png|gif|jpg|jpeg)/
        link = %[<img src="data:#{mime_type},#{src}" alt="#{label}"/>]
      else
        link = %[<a href="data:#{mime_type},#{src}">#{label}</a>]
      end
    else
      ## random raw data
      unless mime_type =~ /^[-a-zA-Z0-9_]+\/[-a-zA-Z0-9_+.;=]+$/
        mime_type = "application/octet-stream"
      end
      link = %[<a href="data:#{mime_type};base64,#{Base64.strict_encode64 src}">#{label}</a>]
    end
    msg = %Q[<div class="step_line_container step_line_info">#{link}</div>\n]

    def msg.html_safe?
      true
    end

    @step_messages << msg
  end

  ################## END FORMATTER HOOKS ####################

  # @return [String] directory to attach artifacts from
  # @note deal with creation and uploading of scenario html log
  def process_scenario_log(opts={})
    if @feature and @scenario
      if opts[:before_failed]
        # lets give a clue in html log what went wrong
        @scenario[:steps].unshift(
          { :status=>:failed,
            :name=>'<div class="step_name step_fail">Before hook failed</div>',
            :messages=>["[42:42:42] ERROR> See console log for actual errors"]
          }
        )
      elsif opts[:after_failed]
        # lets give a clue in html log what went wrong
        @scenario[:steps].unshift(
          { :status=>:failed,
            :name=>'<div class="step_name step_fail">After hook failed</div>',
            :messages=>[]
          }
        )
      else
        # if a scenario is skipped then :status is :failed (in 1.3 at least)
        # we want to correct that unless Before hook raised an error
        @scenario[:status] = self.scenario_status(@scenario)
      end

      gen_html_file(@scenario, @feature[:name]) if @scenario[:status]!=:skipped

      # dir would usually be removed soon
      return scenario_artifacts_dir(@scenario)
    end
  end

  # Methods for generating html files
  def gen_step_name(keyword, step_match, status, file_colon_line, source_indent)
    css_class = case status
      when :passed then 'step_pass'
      when :skipped then 'step_skip'
      else 'step_fail'
    end
    keyword = %Q[<span class="step_keyword">#{keyword}</span>]
    if step_match.class == Cucumber::StepMatch
      step_name = "#{step_match.format_args(lambda {|arg| %Q[<span class="step_arg">#{arg}</span>]})}"
    else
      step_name = "#{step_match.name}"
    end
    return %Q[<div class="step_name #{css_class}">#{keyword}#{step_name} ==>@&nbsp; #{gen_repo_link(file_colon_line)}</div>]
  end

  # TODO: change this to check whether file is part of HOME, PRIVATE_DIR or
  #       tierN repo to generate appropriate links
  def gen_repo_url(file_colon_line)
    file, none, line = file_colon_line.rpartition(":")
    url = conf[:git_repo_url].dup
    url << "/blob/"
    url << GIT_HASH == :unknown ? conf(:git_repo_default_branch) : GIT_HASH
    url << "/" << file
    # need to escape file path above because encode/escape method is deprecated
    # see https://bugs.ruby-lang.org/issues/4167
    url = URI.encode_www_form_component(url)
    url << '#L' << line
    return url
  end

  def gen_repo_link(file_colon_line)
    %Q^<a href="#{gen_repo_url(file_colon_line)}">#{file_colon_line}</a>^
  end

  # TODO: handle PRIVATE source files by delegating all file_colon_line to
  #   [#gen_repo_url]
  def gen_repo_links_in_backtrace(backtrace)
    backtrace.map do |el|
      el_orig = el.dup
      file_colon_line = el.slice!(/^[-._a-zA-Z0-9\/]+:[0-9]+(?=:in)/)
      if file_colon_line && Pathname.new(file_colon_line).relative?
        file_colon_line.slice!("./")
        gen_repo_link(file_colon_line) + el
      else
        el_orig
      end
    end
  end

  def build_step_text_line(step_line)
    step_line = to_utf8 step_line
    # <br> not needed as we use `white-space: pre-wrap;` in css
    step_line = CGI.escapeHTML(step_line).lines.to_a.join #('<br />')
    if step_line =~ /ERROR>/
      css_class = 'step_line_error'
    elsif step_line =~ /WARN>/
      css_class = 'step_line_warn'
    else
      css_class = 'step_line_info'
    end
    step_line.gsub!(/[^[:print:]]\[\d+m/, '') # remove ascii color codes
    step_line.sub!(/[A-Z]+>\s*/, '')
    if step_line =~ /(?<=\[)\d+:\d+:\d+(?=\])/
      time_stamp = Regexp.last_match.to_s
      step_line.sub!(/\[\d+:\d+:\d+\]/, %Q[<span class="time_stamp">#{time_stamp}</span>])
    end
    %Q[<div class="step_line_container #{css_class}">#{step_line}</div>\n]
  end

  def build_step(step_hash)
    # multiline args
    if step_hash[:multiline_arg]
      if step_hash[:multiline_arg].class.to_s.include? "Table"
        # cucumber 1.x using Cucumber::Ast::Table
        # cucumber 2.x - Cucumber::MultilineArgument::DataTable
        multiline_args = step_hash[:multiline_arg].raw.map do |row|
          cols = row.map {|col| "<td>#{CGI.escapeHTML(col)}</td>"}
          "<tr>#{cols.join}</tr>"
        end
        multiline_args = %Q[<div class="multi_arg_container">\n<table>#{multiline_args.join("\n")}</table>\n</div>\n]
      elsif step_hash[:multiline_arg].class.to_s.include? "Empty"
        # in 2.x and :multiline_arg is not nil of false but:
        #   Cucumber::Core::Ast::EmptyMultilineArgument
        multiline_args = nil
      else # Cucumber::Ast::DocString
        multiline_args = "<pre>#{CGI.escapeHTML(step_hash[:multiline_arg])}</pre>"
      end
    else
      multiline_args = nil
    end
    # step messages
    step_lines = build_step_text_lines(step_hash[:messages])
    # backtrace
    if step_hash[:backtrace]
      backtrace = to_utf8 %Q[<div class="step_backtrace">#{step_hash[:backtrace].join('<br />')}</div>\n]
    else
      backtrace = nil
    end
    return %Q[<div class="step_container">#{step_hash[:name]}\n#{multiline_args}#{step_lines}#{backtrace}</div>]
  end

  def build_step_text_lines(message_array)
    step_lines = message_array.map do |step_line|
      if step_line.respond_to?(:html_safe?) && step_line.html_safe?
        step_line
      else
        build_step_text_line step_line
      end
    end
    if step_lines.empty?
      step_lines = nil
    else
      step_lines = %Q[<div class="step_message_container">#{step_lines.join}</div>\n]
    end
  end

  def build_scenario(scenario_hash, feature_name)
    scenario_hash[:name] = scenario_hash[:name].lines.to_a.join('<br />')
    feature_name = feature_name.lines.to_a.join('<br />')

    before_scenario = build_step_text_lines(scenario_hash[:before])
    after_scenario = build_step_text_lines(scenario_hash[:after])

    steps = scenario_hash[:steps].map {|step| self.build_step(step)}.join("\n")

    # css
    if scenario_hash[:status] == :passed
      status = 'pass'
    else
      status = 'fail'
    end

    # Scenario name
    if scenario_hash[:arg]
      scenario_name = %Q[#{scenario_hash[:name]},  Outline arguments: <span class="step_arg">#{scenario_hash[:arg]}</span>]
    else
      scenario_name = scenario_hash[:name]
    end
    scenario_name = %Q[<div class="scenario_name scenario_name_#{status}">Scenario: #{scenario_name} ==>@&nbsp; #{scenario_hash[:file_colon_line]}</div>]
    feature_name = %Q[<div class="feature_name feature_name_#{status}">Feature: #{feature_name}</div>]
    if build_url = ENV['BUILD_URL'] # yes, assignment
      build_url = "http://#{build_url}" unless build_url.slice(/[\w+]+:\/\//)
      scenario_name = %Q[<div class="scenario_name scenario_name_#{status}">Jenkins build URL: <a href="#{build_url}">#{build_url}</a></div>] + scenario_name
    end
    return %Q[<div class="feature_container">#{feature_name}\n<div class="scenario_container">#{scenario_name}\n#{before_scenario}\n#{steps}\n#{after_scenario}</div></div>\n]
  end

  def html_filename(scenario_hash)
    return "console.html"
    # return "#{scenario_normalized_name(scenario_hash)}.html"
  end

  # limits a string length adding crc32 as a suffix for the truncated chars
  # @return unmodified string or truncated string + crc32 suffix
  def str_truncate(str, max_chars=100)
    if str.length <= max_chars
      return str
    else
      keep_str = str[0..max_chars-12]
      rem_str = str[max_chars-11..-1]
      crc32 = Zlib::crc32(rem_str).to_s.rjust(10, "0")
      return "#{keep_str}_#{crc32}"
    end
  end

  def scenario_normalized_name(scenario_hash)
    if scenario_hash[:normalized_name]
      return scenario_hash[:normalized_name]
    else
      arg = scenario_hash[:arg] ? scenario_hash[:arg].strip.gsub(/\s\|\s/,"-").gsub(/[^a-zA-Z0-9-]+/,"_" ).gsub(/_+/,"_").gsub(/^_|_$/,"") : nil
      name = scenario_hash[:name].strip.gsub(/\s\|\s/,"-").gsub(/[^a-zA-Z0-9-]+/,"_" ).gsub(/_+/,"_").gsub(/^_|_$/,"")
      scenario_hash[:normalized_name] = arg ? "#{name}-#{arg}" : "#{name}"
      return scenario_hash[:normalized_name]
    end
  end

  def scenario_artifacts_dir(scenario_hash)
    if scenario_hash[:artifacts_dir]
      return scenario_hash[:artifacts_dir]
    else
      scenario_hash[:artifacts_dir] = File.join(
        @log_dir,
        str_truncate(scenario_normalized_name(scenario_hash))
      )
      FileUtils.mkdir_p(scenario_hash[:artifacts_dir])
      return scenario_hash[:artifacts_dir]
    end
  end

  def gen_html_file(scenario_hash, feature_name)
    html_body = self.build_scenario(scenario_hash, feature_name)
    file_name = self.html_filename(scenario_hash)
    file_path = File.join(
      scenario_artifacts_dir(scenario_hash),
      file_name
    )
    File.write(file_path, @template.gsub(/#HTML_BODY#/) { html_body })
  rescue => e
    output = "Failed to generate log HTML file for scenario: " \
             "#{scenario_hash[:name]}, #{scenario_hash[:arg]}\n" \
             "#{exception_to_string(e)}\n"
    @io.write(output)
    Kernel.puts(output)
  end

  def scenario_status(scenario_hash)
    passed_count, failed_count, skipped_count = 0, 0, 0
    scenario_hash[:steps].each do |step|
      if step[:status] == :passed
        passed_count += 1
      elsif step[:status] == :failed or step[:status] == :undefined
        failed_count += 1
      elsif step[:status] == :skipped
        skipped_count += 1
      else
        raise "Invalid step status: #{step[:status]}"
      end
    end
    if failed_count > 0
      return :failed
    elsif passed_count == scenario_hash[:steps].length
      return :passed
    elsif skipped_count == scenario_hash[:steps].length
      return :skipped
    else
      @io.write("Warning!!! passed: #{passed_count}, failed: #{failed_count}, skipped: #{skipped_count}, total steps: #{scenario_hash[:steps].length}\n")
      return :failed
    end
  end
end
end
