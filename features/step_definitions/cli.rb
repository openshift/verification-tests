## Put here steps that are mostly cli specific, e.g new-app
When /^I run the :(.*?) client command$/ do |yaml_key|
  yaml_key.sub!(/^:/,'')
  @result = user.cli_exec(yaml_key.to_sym, {})
end

Given /^oc major.minor version is stored in the#{OPT_SYM} clipboard$/ do |cb_name|
  @result = user.cli_exec(:version)
  cb_name ||= "oc_version"
  cb[cb_name] = @result[:props][:oc_version].split(".")[0..1].join(".")
end

When /^I run the :([a-z_]*?)( background)? client command with:$/ do |yaml_key, background, table|
  if background
    @result = user.cli_exec(
      yaml_key.to_sym,
      opts_array_process(table.raw) << [ :_background, true ]
    )
    @bg_rulesresults << @result
    @bg_processes << @result[:process_object]
  else
    @result = user.cli_exec(yaml_key.to_sym, opts_array_process(table.raw))
  end
end

When /^I run the :([a-z_]*?)( background)? admin command$/ do |yaml_key, background|
  step "I run the :#{yaml_key}#{background} admin command with:",
    table([["dummy"]])
end

When /^I run the :([a-z_]*?)( background)? admin command with:$/ do |yaml_key, background, table|
  ensure_admin_tagged
  opts = table.raw == [["dummy"]] ? [] : opts_array_process(table.raw)

  if background
    @result = env.admin.cli_exec(
      yaml_key.to_sym,
      opts << [ :_background, true ]
    )
    @bg_rulesresults << @result
    @bg_processes << @result[:process_object]
  else
    @result = env.admin.cli_exec(yaml_key.to_sym, opts)
  end
end

# there is no such thing as app in OpenShift but there is a command new-app
#   in the cli that logically represents an app - creating/deploying different
#   pods, services, etc.; There is a discussion coing on to rename and refactor
#   the funcitonality. Not sure that goes anywhere but we could adapt this
#   step for backward compatibility if needed.
Given /^I create a new application with:$/ do |table|
  step 'I run the :new_app client command with:', table
end

# instead of writing multiple steps, this step does this in one go:
# 1. download file from JSON/YAML URL
# 2. replace any path with given value from table
# 3. runs `oc create` command over the resulting file
When /^I run oc create( as admin)? (?:over|with) #{QUOTED} replacing paths:$/ do |admin, file, table|
  if file.include? '://'
    step %Q|I download a file from "#{file}"|
    resource_hash = YAML.load(@result[:response])
  else
    resource_hash = YAML.load_file(expand_path(file))
  end

  # replace paths from table
  table.raw.each do |path, value|
    eval "resource_hash#{path} = YAML.load value"
    # e.g. resource["spec"]["nfs"]["server"] = 10.10.10.10
    #      resource["spec"]["containers"][0]["name"] = "xyz"
  end
  resource = resource_hash.to_json
  logger.info resource

  if admin
    ensure_admin_tagged
    @result = self.admin.cli_exec(:create, {f: "-", _stdin: resource})
  else
    @result = user.cli_exec(:create, {f: "-", _stdin: resource})
  end
end

When /^I run oc replace( as admin)? (?:over|with) #{QUOTED} replacing paths:$/ do |admin, file, table|
  if file.include? '://'
    step %Q|I download a file from "#{file}"|
    resource_hash = YAML.load(@result[:response])
  else
    resource_hash = YAML.load_file(expand_path(file))
  end

  # replace paths from table
  table.raw.each do |path, value|
    eval "resource_hash#{path} = YAML.load value"
    # e.g. resource["spec"]["nfs"]["server"] = 10.10.10.10
    #      resource["spec"]["containers"][0]["name"] = "xyz"
  end
  resource = resource_hash.to_json
  logger.info resource

  if admin
    ensure_admin_tagged
    @result = self.admin.cli_exec(:replace, {f: "-", _stdin: resource})
  else
    @result = user.cli_exec(:replace, {f: "-", _stdin: resource})
  end
end

# instead of writing multiple steps, this step does this in one go:
# 1. download file from URL
# 2. load it as an ERB file with the cucumber scenario variables binding
# 3. runs `oc create` command over the resulting file
When /^I run oc create( as admin)? over ERB test file: (.*)$/ do |admin, file_path|
  step %Q|I obtain test data file "#{file_path}"|
  file_path = cb.test_file
  # overwrite with ERB loaded content
  loaded = ERB.new(File.read(file_path)).result binding
  File.write(file_path, loaded)
  if admin
    ensure_admin_tagged
    @result = self.admin.cli_exec(:create, {f: file_path})
  else
    @result = user.cli_exec(:create, {f: file_path})
  end
end

#@param file
#@notes Given a remote (http/s) or local file, run the 'oc process'
#command followed by the 'oc create' command to save space
When /^I process and create #{QUOTED}$/ do |file|
  step 'I process and create:', table([["f", file]])
end

#@param template
#@notes Given a remote (http/s) or local template, run the 'oc process'
#command followed by the 'oc create' command to save space
When /^I process and create template #{QUOTED}$/ do |template|
  step 'I process and create:', table([["template", template]])
end

# process file/url with parameters, then feed into :create
When /^I process and create:$/ do |table|
  # run the process command, then pass it in as stdin to 'oc create'
  process_opts = opts_array_process(table.raw)
  process_opts << [:_stderr, :stderr]
  @result = user.cli_exec(:process, process_opts)
  if @result[:success]
    @result = user.cli_exec(:create, {f: "-", _stdin: @result[:stdout]})
  end
end

# this step basically wraps around the steps we use for simulating 'oc edit <resource_name'  which includes the following steps:
# #   1.  When I run the :get client command with:
#       | resource      | dc |
#       | resource_name | hooks |
#       | o             | yaml |
#     And I save the output to file> hooks.yaml
#     And I replace lines in "hooks.yaml":
#       | 200 | 10 |
#       | latestVersion: 1 | latestVersion: 2 |
#     When I run the :replace client command with:
#       | f      | hooks.yaml |
#  So the output file name will be hard-coded to 'tmp_out.yaml', we still need to
#  supply the resouce_name and the lines we are replacing
Given /^(?:(as admin) )?I replace resource "([^"]+)" named "([^"]+)"(?: saving edit to "([^"]+)")?:$/ do |as_admin, resource, resource_name, filename, table |
  filename = "edit_resource.yaml" if filename.nil?
  if as_admin.nil?
    as_user = "client"
  else
    as_user = "admin"
  end
  step %Q/I run the :get #{as_user} command with:/, table(%{
    | resource | #{resource} |
    | resource_name |  #{resource_name} |
    | o | yaml |
    })
  step %Q/the step should succeed/
  step %Q/I save the output to file> #{filename}/
  step %Q/I replace content in "#{filename}":/, table
  step %Q/I run the :replace #{as_user} command with:/, table(%{
    | f | #{filename} |
    })
end

Given /^I wait(?: up to #{NUMBER} seconds)? for the last background process to finish$/ do |seconds|
  seconds = Integer(seconds) rescue 60
  success = wait_for(seconds) { @bg_processes.last.finished? }
  raise "last process did not finish within #{seconds} seconds" unless success
end

Given /^I terminate last background process$/ do
  if @bg_processes.last.finished?
    raise "last process already finished: #{@bg_processes.last}"
  end

  @bg_processes.last.kill_tree
  @result = @bg_processes.last.result
end

Given /^I check status of last background process$/ do
  @bg_processes.last.wait(10)
  @result = @bg_processes.last.result
end

# This step needs flexibly specify table.
# A. When the expected json is just == the patch json, the step only needs specify one-unit table, like:
#     | {"spec":{"replicas":2}} |
# B. Otherwise, the step needs specify four-unit table, like (explained below):
#     | patch  | {"metadata":{"labels":{"labelname": null}}} |
#     | expect | {"metadata":{"labels":null}}                |
# A is the most frequent situation when using oc patch without 'null' in patch json.
# B is the situation when the expected json != the patch json, though the patch succeeds.
# E.g. if the resource has ONLY ONE label and we remove it, the "labels" key will be removed together, so
# the expected json should be {"metadata":{"labels":null}}.
Given /^(?:(as admin) )?I successfully#{OPT_WORD} patch resource "(.*)\/(.*)" with:$/ do |as_admin, patch_type, resource_type, resource_name, table|
  if table.raw[1]
    hash = table.rows_hash
    patch_json = hash["patch"]
    expect_hash = YAML.load(hash["expect"])
  elsif
    patch_json = table.raw[0][0]
    expect_hash = YAML.load(patch_json)
  end
  if as_admin.nil?
    _user = user
  else
    ensure_admin_tagged
    _user = admin
  end

  opts = {resource: resource_type, resource_name: resource_name, p: patch_json, type: patch_type}
  res = _user.cli_exec(:patch, **opts)
  unless res[:success]
    logger.error(res[:response])
    raise "Failed to patch #{resource_type} #{resource_name} with #{patch_json}"
  end

  if patch_type != "json" # below substruct? does not apply for json patch
    opts = {resource: resource_type, resource_name: resource_name, o: "yaml", _quiet: true}
    sec = 30
    failpath = nil
    success = wait_for(sec) {
      failpath = []
      res = _user.cli_exec(:get, **opts)
      substruct?(expect_hash, res[:parsed], vague_nulls: true, failpath: failpath, exact_arrays: true, null_deletes_key: true)
    }

    if ! success
      raise "patch failed to apply at #{failpath}! #{@result[:response]}"
    end
  end
end

