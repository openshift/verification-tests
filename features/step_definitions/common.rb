require 'json'
require 'yaml'

Then /^the step should( not)? (succeed|fail)$/ do |negative, outcome|
  if ((outcome == "succeed") ^ negative ) != @result[:success]
    raise "the step #{@result[:success] ? "succeeded" : "failed"}"
  end
end

Given /^the step (succeeded|failed)$/ do |outcome|
  if (outcome == "succeeded") != @result[:success]
    raise "the step #{@result[:success] ? "succeeded" : "failed"}"
  end
end

# @note This step checks whether or not a step successfully timed out
Then /^the step should have timed out$/ do
  raise "The step did not timeout" unless @result[:timeout]
end

When /^I perform the :([a-z_]*?) rest request$/ do |yaml_key|
  @result = user.rest_request(yaml_key.to_sym)
end

When /^I perform the :([a-z_]*?) rest request with:$/ do |yaml_key, table|
  @result = user.rest_request(yaml_key.to_sym, opts_array_to_hash(table.raw))
end

# @param [String] negative Catches "not" if it is present
# @param [Table] Array of the strings we are searching for
# @note Checks whether the output contains/(does not contain) any of the
# strings or regular expressions listed in the given table
Then /^(the|all)? outputs?( by order)? should( not)? (contain|match)(?: (\d+) times)?:$/ do |all, in_order, negative, match_type, times, table|
  raise "incompatible options 'times' and 'by order'" if times && in_order
  if all == "all"
    case
    when @result.kind_of?(Array)
      outputs = @result.map {|r| r[:response].to_s}
    when @result[:response].kind_of?(Array)
      outputs = @result[:response].map(&:to_s)
    else
      outputs = [ @result[:response].to_s ]
    end
  else
    outputs = [ @result[:response].to_s ]
  end

  if match_type == "match"
    patterns = table.raw.map {|p| Regexp.new(p.first)}
  else
    patterns = table.raw.map(&:first)
  end

  times = Integer(times) if times

  outputs.each do |o|
    case
    when times
      patterns.each do |p|
        found_times = o.scan(p).size
        unless (found_times == times) ^ negative
          raise "found pattern #{found_times} times with baseline #{times} times: #{p}"
        end
      end
    when in_order
      i = 0
      pattern = "nil"
      found = false
      patterns.each do |p|
        pattern = p
        if p.kind_of? Regexp
          match = p.match(o, i)
          if match
            found = true
            i = match.end(0)
          else
            found = false
            break
          end
        else
          match = o.index(p, i)
          if match
            found = true
            i = match + p.size
          else
            found = false
            break
          end
        end
      end
      if !found && !negative
        raise "pattern #{pattern} not found in specified order"
      elsif found && negative
        raise "all patterns found in specified order"
      end
    else
      patterns.each do |p|
        if p.kind_of? Regexp
          found = !!o.match(p)
        else
          found = o.include? p
        end
        raise "pattern#{negative ? "" : " not"} found: #{p}" unless found ^ negative
      end
    end
  end
end

# @param [String] negative Catches "not" if it is present
# @param [Table] Array of the strings we are searching for
# @note Checks whether the output contains/(does not contain) any of the
# strings or regular expressions listed in the given table
Then /^(the|all)? outputs?( by order)? should( not)? (contain|match) "(.+)"(?: (\d+) times)?$/ do |all, in_order, negative, match_type, pattern, times|
  step "#{all} output#{in_order} should#{negative} #{match_type}#{times}:",
    table([[pattern]])
end

Then /^the output should equal #{QUOTED}$/ do |value|
  unless value.strip == @result[:response].strip
    raise "output does not equal expected value, see log"
  end
end

Given /^([0-9]+?) seconds have passed$/ do |num|
  sleep(num.to_i)
end

Given /^evaluation of `(.+?)` is stored in the#{OPT_SYM} clipboard$/ do |what, clipboard_name|
  clipboard_name = 'tmp' unless clipboard_name
  cb[clipboard_name] = eval(what)
end

Then /^(?:the )?expression should be true> (.+)$/ do |expr|
  res = eval expr
  eval_details = ""
  unless res
    ruby_special_op = /\?/
    unless expr.scan(ruby_special_op).count > 0
      # try to print out the left and right operand values to help with debugging
      # please note the order of the operator matters
      comparison_operators = /===|==|>=|<=|!=|>|<|&&|\|\|&|\|/
      op = expr.scan(comparison_operators).first
      if op
        e1, e2 = expr.split(op)
        # XXX: we may not catch everything, wrap it around begin/rescue and print
        # out blank if some complex comparison is in the expression.
        begin
          eval_details = "\nleft_operand: #{eval(e1)}, right_operand: #{eval(e2)}\n"
        rescue
          logger.info("Unable to interpret the expression...")
        end
      end
    else
      logger.info("singular expression detected skipping left & right operand eval() ...")
    end
    raise "expression \"#{expr}\" returned non-positive status: #{res}" + eval_details
  end
end

Given /^an?(?: (\d+) characters?)? random string(?: of type :(.*?))? is (?:saved|stored) into the(?: :(.*?))? clipboard$/ do |chars, rand_type, clipboard_name|
  chars = 8 unless chars
  rand_type = rand_type.to_sym unless rand_type.nil?
  rand_str = rand_str(chars.to_i, rand_type)
  clipboard_name = 'tmp' unless clipboard_name
  cb[clipboard_name] = rand_str
end

Given /^the output is parsed as (YAML|JSON)$/ do |format|
  case format
  when "YAML"
    @result[:parsed] = YAML.load @result[:response]
  when "JSON"
    @result[:parsed] = JSON.load @result[:response]
  else
    raise "unknown format: #{format}"
  end
end

Given /^feature gate "(.+)" is (enabled|disabled)(?: with admission#{OPT_QUOTED} (enabled|disabled)?)?$/ do |fg, fgen, adm, admen|
  ensure_destructive_tagged
  fg_en = (fgen == "enabled")
  env.master_services.each { |service|
    master_config = service.config
    config_hash = master_config.as_hash()
    config_hash["kubernetesMasterConfig"] ||= {}
    config_hash["kubernetesMasterConfig"]["apiServerArguments"] ||= {}
    config_hash["kubernetesMasterConfig"]["apiServerArguments"]["feature-gates"] ||= []
    config_hash["kubernetesMasterConfig"]["controllerArguments"] ||= {}
    config_hash["kubernetesMasterConfig"]["controllerArguments"]["feature-gates"] ||= []
    api_fg = config_hash["kubernetesMasterConfig"]["apiServerArguments"]["feature-gates"]
    controller_fg = config_hash["kubernetesMasterConfig"]["controllerArguments"]["feature-gates"]
    unless api_fg && api_fg.include?("#{fg}=#{fg_en}") &&
           controller_fg && controller_fg.include?("#{fg}=#{fg_en}")
      config_hash["kubernetesMasterConfig"]["apiServerArguments"]["feature-gates"].delete("#{fg}=#{! fg_en}")
      config_hash["kubernetesMasterConfig"]["controllerArguments"]["feature-gates"].delete("#{fg}=#{! fg_en}")
      if fg_en
        config_hash["kubernetesMasterConfig"]["apiServerArguments"]["feature-gates"] << "#{fg}=true"
        config_hash["kubernetesMasterConfig"]["controllerArguments"]["feature-gates"] << "#{fg}=true"
      end
      update_api_controller = true
    end
    if adm
      adme_da = !(admen == "enabled")
      config_hash["admissionConfig"] ||= {}
      config_hash["admissionConfig"]["pluginConfig"] ||= {}
      config_hash["admissionConfig"]["pluginConfig"]["#{adm}"] ||= {}
      config_hash["admissionConfig"]["pluginConfig"]["#{adm}"]["configuration"] ||= {}
      unless config_hash["admissionConfig"]["pluginConfig"]["#{adm}"]["configuration"].include?("disable") &&
             config_hash["admissionConfig"]["pluginConfig"]["#{adm}"]["configuration"]["disable"] == adme_da
        adm_yml =  {"#{adm}" =>
                     {"configuration" => {"apiVersion" => "v1",
                                           "disable" => adme_da,
                                           "kind" => "DefaultAdmissionConfig"}}}
        config_hash["admissionConfig"]["pluginConfig"].delete("#{adm}")
        config_hash["admissionConfig"]["pluginConfig"].merge!(adm_yml)
        update_adm = true
      end
    end
    if update_api_controller || update_adm
      step 'master config is merged with the following hash:', config_hash.to_yaml
      service.restart(raise: true)
    end
  }
#  step 'the master service is restarted on all master nodes'

  nodes = env.nodes.select { |n| n.schedulable? }
  cache_resources *nodes
  nodes.each { |node|
    nodename = node.name
    node_config = node.service.config
    config_hash = node_config.as_hash()
    config_hash["kubeletArguments"] ||= {}
    config_hash["kubeletArguments"]["feature-gates"] ||= []
    kubelet_fg = config_hash["kubeletArguments"]["feature-gates"]
    unless kubelet_fg && kubelet_fg.include?("#{fg}=#{fg_en}")
      config_hash["kubeletArguments"]["feature-gates"].delete("#{fg}=#{! fg_en}")
      if fg_en
        config_hash["kubeletArguments"]["feature-gates"] << "#{fg}=true"
      end
      step %Q/I use the "#{nodename}" node/
      step "node config is merged with the following hash:", config_hash.to_yaml
      step "the node service is restarted on the host"
    end
  }
end

Given /^I check feature gate #{QUOTED}(?: with admission #{QUOTED})? is enabled$/ do |fg, adm|
  non_default_feature_gates_3_11 = Set[
    'BlockVolume'
  ]
  non_default_feature_gates_3_10 = Set[
    'BlockVolume',
    'ExpandPersistentVolumes'
  ]
  non_default_feature_gates_3_9 = Set[
    'BlockVolume',
    'ExpandPersistentVolumes',
    'MountPropagation',
    'PersistentLocalVolumes',
    'PVCProtection'
  ]
  if (env.version_eq("3.11", user: user) && non_default_feature_gates_3_11.include?("#{fg}")) ||
     (env.version_eq("3.10", user: user) && non_default_feature_gates_3_10.include?("#{fg}")) ||
     (env.version_eq("3.9", user: user) && non_default_feature_gates_3_9.include?("#{fg}"))
    env.master_services.each { |service|
      master_config = service.config
      config_hash = master_config.as_hash()
      if config_hash["kubernetesMasterConfig"]["apiServerArguments"]["feature-gates"] == nil ||
           !config_hash["kubernetesMasterConfig"]["apiServerArguments"]["feature-gates"].join(",").include?("#{fg}=true") ||
           config_hash["kubernetesMasterConfig"]["controllerArguments"]["feature-gates"] == nil ||
           !config_hash["kubernetesMasterConfig"]["controllerArguments"]["feature-gates"].join(",").include?("#{fg}=true")
        raise "feature gate #{fg} is not enabled on the master, please enable it first"
      end
      if adm && (config_hash.dig("admissionConfig", "pluginConfig", adm, "configuration").nil? || config_hash["admissionConfig"]["pluginConfig"]["#{adm}"]["configuration"]["disable"])
        raise "admission controller #{adm} is not enabled, please enable it first"
      end
    }

    nodes = env.nodes.select { |n| n.schedulable? }
    cache_resources *nodes
    nodes.each { |node|
      nodename = node.name
      node_config = node.service.config
      config_hash = node_config.as_hash()
      if config_hash["kubeletArguments"]["feature-gates"] == nil || !config_hash["kubeletArguments"]["feature-gates"].join(",").include?("#{fg}=true")
        raise "feature gate #{fg} is not enabled on the node #{nodename}, please enable it first"
      end
    }
  end
end

Given /^I saved following keys to list in #{SYM} clipboard:$/ do |cbsym, table|
  options = hash_symkeys(table.rows_hash)
  cb[cbsym]= options.keys
end
