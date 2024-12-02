Given /^there is no (\w+) in the#{OPT_QUOTED} project$/ do |resource, project_name|
  project_name = ' "' + project_name + '"' if project_name
  @result = user.cli_exec(:get, resource: resource, n: project_name)
  step %Q/the output should match "No resources found"/
end

Given /^I have a project$/ do
  # system projects should not be selected by default
  sys_projects = BushSlicer::Project::SYSTEM_PROJECTS

  project = @projects.reverse.find {|p|
    !sys_projects.include?(p.name) &&
      p.is_user_admin?(user: user, cached: true) &&
      p.active?(user: user, cached: true)
  }
  if project
    # project does exist as visible is doing an actual query
    # also move project up the stack
    @projects << @projects.delete(project)
  else
    projects = (user.projects - sys_projects).select {|p|
      p.is_user_admin?(user: user, cached: true) &&
      p.active?(user: user, cached: true)
    }
    if projects.empty?
      step 'I create a new project'
      unless @result[:success]
        logger.error(@result[:response])
        raise "unable to create project, see log"
      end
    else
      cache_resources *projects
    end
  end
end

Given /^I have a project with proper privilege$/ do
  step %Q/I have a project/
  step %Q/the appropriate pod security labels are applied to the namespace/
end

Given /^the appropriate pod security labels are applied to the#{OPT_QUOTED} namespace$/ do | project_name |
  ensure_admin_tagged
  project_name ||= project.name
  if env.version_ge("4.12", user: user) or env.version_eq("4.2", user: user)
    admin.cli_exec(:label, resource: "namespace", name: project_name, key_val: 'security.openshift.io/scc.podSecurityLabelSync=false', overwrite: true)
    admin.cli_exec(:label, resource: "namespace", name: project_name, key_val: 'pod-security.kubernetes.io/enforce=privileged', overwrite: true)
    admin.cli_exec(:label, resource: "namespace", name: project_name, key_val: 'pod-security.kubernetes.io/audit=privileged', overwrite: true)
    admin.cli_exec(:label, resource: "namespace", name: project_name, key_val: 'pod-security.kubernetes.io/warn=privileged', overwrite: true)
  end
end

# try to create a new project with current user
When /^I create a new project(?: via (.*?))?$/ do |via|
  @result = BushSlicer::Project.create(by: user, name: rand_str(5, :dns), _via: (via.to_sym if via))
  if @result[:success]
    @projects << @result[:project]
    @result = @result[:project].wait_to_be_created(user)
    unless @result[:success]
      logger.warn("Project #{@projects.last.name} not visible on server after create")
    end
    if via == "web"
      cache_browser(user.webconsole_executor)
      # switch automatically when creating via web
      step %Q/I use the "#{@projects.last.name}" project/
    end
  end
end

# create a new project w/o leading digit to get around this java bug.
# Use this step to create a project for logging and metrics tests
# https://stackoverflow.com/questions/33827789/self-signed-certificate-dnsname-components-must-begin-with-a-letter
# https://bugs.openjdk.java.net/browse/JDK-8054380
Given /^I create a project with non-leading digit name$/ do
  @result = BushSlicer::Project.create(by: user, name: rand_str(5, :dns952))
  if @result[:success]
    @projects << @result[:project]
    @result = @result[:project].wait_to_be_created(user)
    unless @result[:success]
      logger.warn("Project #{@projects.last.name} not visible on server after create")
    end
  end
end

# create a new project w/ a leading digit to test OVS quoting
Given /^I create a project with leading digit name$/ do
  name = rand_str(5, :num) + rand_str(3, :dns952)
  @result = BushSlicer::Project.create(by: user, name: name)
  if @result[:success]
    @projects << @result[:project]
    @result = @result[:project].wait_to_be_created(user)
    unless @result[:success]
      logger.warn("Project #{@projects.last.name} not visible on server after create")
    end
  end
end

# create x number of projects
Given /^I create (\d+) new projects?$/ do |num|
  (1..Integer(num)).each {
    step 'I create a new project'
    unless @result[:success]
      logger.error(@result[:response])
      raise "unable to create project, see log"
    end
  }
end

# create a new project with user options,either via web or cli
When /^I create a project via (.+?) with:$/ do |via, table|
  opts = opts_array_to_hash(table.raw)
  @result = BushSlicer::Project.create(by: user, name: rand_str(5, :dns), _via: (via.to_sym if via), **opts)
  if @result[:success]
    @projects << @result[:project]
    @result = @result[:project].wait_to_be_created(user)
    unless @result[:success]
      logger.warn("Project #{@projects.last.name} not visible on server after create")
    end
    if via == "web"
      cache_browser(user.webconsole_executor)
      step %Q/I use the "#{@projects.last.name}" project/
    end
  end
end

Given /^I use the "(.+?)" project$/ do |project_name|
  # this would find project in cache and move it up the stack
  # or create a new BushSlicer::Project object and put it on top of stack
  project(project_name)

  # setup cli to have it as default project
  @result = user.cli_exec(:project, project_name: project_name)
  unless @result[:success]
    raise "can not switch to project #{project.name}"
  end
end

Given /^admin uses the "(.+?)" project$/ do |project_name|
  ensure_admin_tagged

  project(project_name)
  @result = admin.cli_exec(:project, project_name: project_name)
  unless @result[:success]
    raise "can not switch to project #{project.name}"
  end
end

Given /^I imagine a project$/ do
  project(rand_str(5, :dns))
end

When /^admin creates a project$/ do
  ensure_admin_tagged

  project(rand_str(5, :dns))

  # first make sure we clean-up this project at the end
  _project = project # we need variable for the teardown proc
  teardown_add { @result = _project.delete(by: :admin) }

  # create with raw command to avoid safety project without admin user check in
  #   Project#create method
  @result = admin.cli_exec( :oadm_new_project,
                            project_name: project.name,
                            display_name: "Fancy project",
                            description: "OpenShift v3 rocks" )
end

When /^admin creates a project with:$/ do |table|
  ensure_admin_tagged

  opts = opts_array_process(table.raw)
  project_name = opts.find { |o| o[0] == :project_name }
  if project_name
    project_name = project_name[1]
  else
    project_name = rand_str(5, :dns)
    opts << [:project_name, project_name]
  end

  # first make sure we clean-up this project at the end
  _project = project(project_name) # we need variable for the teardown proc
  teardown_add { @result = _project.delete(by: :admin) }

  # create with raw command to avoid safety project without admin user check in
  #   Project#create method
  @result = admin.cli_exec( :oadm_new_project, opts)
end

Given /^admin creates a project with a random schedulable node selector$/ do
  project_name = rand_str(5, :dns)
  step %Q{admin creates a project with:}, table(%{
    | project_name  | #{project_name}       |
    | node_selector | #{project_name}=label |
    })
  step %Q/I store the schedulable workers without taints in the :nodes clipboard/
  step %Q/label "<%= project.name %>=label" is added to the "<%= cb.nodes[0].name %>" node/
  step %Q/the appropriate pod security labels are applied to the namespace/
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "<%= project.name %>" project/
end

When /^admin deletes the #{QUOTED} project$/ do |project_name|
  p = project(project_name)
  @result = p.delete(by: :admin)
  @projects.delete(p) if @result[:success]
end

# tries to delete last used project or a project with given name (if name given)
When /^I delete the(?: "(.+?)")? project$/ do |project_name|
  p = project(project_name)
  @result = project(project_name).delete(by: user)
  if @result[:success]
    @projects.delete(p)
    @result[:success] = p.wait_to_disappear(user)
    unless @result[:success]
      logger.warn("Project #{p.name} still visible on server after delete")
    end
  end
end

Given /^the(?: "(.+?)")? project is deleted$/ do |project_name|
  project_name = ' "' + project_name + '"' if project_name
  step "I delete the#{project_name} project"
  unless @result[:success]
    logger.error(@result[:response])
    raise "unable to delete project, see log"
  end
end

When(/^I delete all resources by labels:$/) do |table|
  @result = project.delete_all_labeled(*table.raw.flatten, by: user)
end

When(/^I delete all resources from the project$/) do
  step %Q/I run the :delete client command with:/, table(%{
    | object_type | all  |
    | all         | true |
  })
  raise "unable to delete all resources, see logs" unless @result[:success]

  step %Q/I run the :delete client command with:/, table(%{
    | object_type | secrets |
    | all         | true    |
  })
  raise "unable to delete secrets, see logs" unless @result[:success]

  deleted = wait_for(120) {
    project.pods(by: user, get_opts: {_quiet: true}).empty?
  }
  unless deleted
    raise "not all pods actually deleted: " \
      "#{project.pods(by: user).map(&:name).join(?,)}"
  end

  step %Q/I run the :delete client command with:/, table(%{
    | object_type | pvc  |
    | all         | true |
  })
  raise "unable to delete pvc, see logs" unless @result[:success]
end


Then(/^the project should be empty$/) do
  @result = project.empty?(user: user)
  unless @result[:success]
    logger.error(@result[:response])
    raise "project not empty, see logs"
  end
end

When /^I get project ([-a-zA-Z_]+) named #{QUOTED}(?: as (YAML|JSON))?$/ do |resource, resource_name, format|
  _resource = resource(resource_name, resource, project_name: project.name)
  @result = _resource.get(user: user)
  if @result[:success] && format == "JSON"
    # this is a hack but it is needed for backward compatibility and it is
    # too ugly to allow #get accept format as a parameter
    @result[:response] = JSON.pretty_generate(
      BushSlicer::Resource.struct_iso8601_time(@result[:parsed])
    )
  end
end

# discouraged
When /^I get project ([-a-zA-Z_]+)$/ do |type|
  @result = user.cli_exec(:get, resource: type, n: project.name)
end

# discouraged
When /^I get project ([-a-zA-Z_]+) with labels:$/ do |resource, table|
  labels = table.raw.flatten
  @result = user.cli_exec(:get, resource: resource, n: project.name, l: labels)
end

When /^I get project ([-a-zA-Z_]+) as (YAML|JSON)$/ do |type, format|
  @result = {}
  clazz = resource_class(type)

  unless BushSlicer::ProjectResource > clazz
    raise "#{clazz} is not a project resource"
  end

  begin
    list = clazz.list(user: user,
                      project: project,
                      result: @result, get_opts: {output: format.downcase})
    cache_resources *list
  rescue
    unless @result.has_key? :success
      # if operation somehow failed but result was generated we let user
      # catch the issue by checking @result, otherwise we raise the original
      # error
      raise
    end
  end
end
