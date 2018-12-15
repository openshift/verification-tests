# helper step for metering scenarios
require 'ssl'
# For metering automation, we just install once and re-use the installation
# unless the scenarios are for testing installation
# checks that metering service is already installed
Given /^metering service has been installed successfully(?: using (ansible|shell script|OLM))?$/ do |method|
  ensure_admin_tagged

  # default to shell script installation until OLM install is supported
  method ||= "shell script"
  case method
  when "shell script"
    namespace = "metering"
    metering_name = "operator-metering"
  when "ansible"
    namespace = "openshift-metering"
    metering_name = "openshift-metering"
  when "OLM"
    namespace = "metering"  # TDB
  end
  # save it to clipboard for future reference
  cb.metering_namespace = namespace

  step %Q/I save the project name hosting "metering" resource named "#{metering_name}" to clipboard/
  # a pre-req is that openshift-monitoring is installed in the system, w/o it
  # the openshift-metering won't function correctly
  unless project('openshift-monitoring').exists?
    raise "service openshift-monitoring is a pre-requisite for #{namespace}"
  end
  # change project context
  unless cb.namespace
    case method
    when "shell script"
      step %Q/metering service is installed using shell script/
    when "ansible"
      # install metering using default
      step %Q/default metering service is installed without cleanup/
    when "OLM"
      raise "OLM installation of metering service is not supported"
    end
  end
  step %Q/all metering related pods are running in the "#{namespace}" project/
  step %Q/I wait for the "#{metering_name}" metering to appear/
end

Given /^default metering service is installed without cleanup$/ do
  step %Q/I create a project with non-leading digit name/
  step %Q/I store master major version in the clipboard/
  step %Q/metering service is installed with ansible using:/, table(%{
    | inventory     | https://raw.githubusercontent.com/openshift-qe/v3-testfiles/master/logging_metrics/default_install_metering_params |
    | playbook_args | -e openshift_image_tag=v<%= cb.master_version %> -e openshift_release=<%= cb.master_version %>                     |
    | no_cleanup    | true                                                                                                               |
  })
  # step %Q/I switch to cluster admin pseudo user/
  # step %Q/I use the "openshift-metering" project/
end

# multiple steps are involved in generating a metering report
# 1. Writing a report: metering Report object is created with user providing
# => a. ReportGenerationQuery
# => b. reportingStart
# => c. reportingEnd
#  it's basically a helper to construct the query of the backend database for a
# 'normal' user without knowledge of the various tables.  To get the list of available
#  ReportGenerationQueries do 'oc get reportgenerationqueries -n $METERING_NAMESPACE'
# 2. Creating a report
# =>

Given /^I get the #{QUOTED} report and store it in the#{OPT_SYM} clipboard using:$/ do |name, cb_name, table|
  ensure_admin_tagged

  cb_name ||= :report
  opts = opts_array_to_hash(table.raw)
  default_start_time = "#{Time.now.year}" + "-01-01T00:00:00Z"
  default_end_time = "#{Time.now.year}" + "-12-30T23:59:59Z"
  default_format = 'json'
  # sanity check
  required_params = [:query_type ]
  required_params.each do |param|
    raise "Missing parameter '#{param}'" unless opts[param]
  end

  query_type = opts[:query_type]  # short hand for reportGenerationQueries
  start_time = opts[:start_time].nil? ? default_start_time : opts[:start_time]
  end_time = opts[:end_time].nil? ? default_end_time : opts[:end_time]
  run_now = opts[:run_now].nil? ? 'true' : opts[:run_now]
  report_format = opts[:format].nil? ? default_format : opts[:format]
  # create the report resource
  opts[:report_yaml] = BushSlicer::Report.generate_yaml(
    query_type: query_type, start_time: start_time, end_time: end_time,
    run_now: run_now) unless opts[:report_yaml]
  logger.info("#### gernated report using the following yaml:\n #{opts[:report_yaml]}")
  report(name).construct(user: user, **opts)
  report(name).wait_till_finished(user: user)
  # report object confirm it's ready to be used, before querying, we need to enable proxy on the host
  host.exec('oc proxy', background: true)
  step %Q/I perform the :view_metering_report rest request with:/, table(%{
    | project_name  | #{project.name}  |
    | name          | #{name}          |
    | report_format | #{report_format} |
    })
  if report_format != 'json' and report_format != 'yaml'
    # just return raw response for not easily parseable formats
    cb[cb_name] = @result[:response].to_s
  else
    cb[cb_name] = @result[:parsed]
  end
end


### set up an app for metering that will be capable of returning valid reports of different types
# #### create an app that will excercise all of the reports
# 1. create a quickstart app with pv
#    - oc new-app --template=django-psql-persistent
# 2. need to patch it since the template does not have 'cpu' limits set under 'resources'.  We MUST see that parameter in order to trigger metrics
#   - oc patch dc/django-psql-persistent  -p '{"spec":{"template":{"spec":{"containers":[{"name":"django-psql-persistent","resources":{"limits":{"memory": "512Mi","cpu": "200m"}}}]}}}}'
# 3. wait for new pod to be created
Given /^I setup an app to test metering reports$/ do
  step %Q/I run the :new_app client command with:/, table(%{
    | template | django-psql-persistent |
  })
  step %Q/the step should succeed/
  step %Q/a deploymentConfig becomes ready with labels:/, table(%{
    | app=django-psql-persistent |
  })
  step %Q/I run the :patch client command with:/, table(%{
    | resource      | deploymentConfig                                                                                                                            |
    | resource_name | django-psql-persistent                                                                                                                      |
    | p             | {"spec":{"template":{"spec":{"containers":[{"name":"django-psql-persistent","resources":{"limits":{"memory": "512Mi","cpu": "200m"}}}]}}}}' |
  })
  step %Q/a pod becomes ready with labels:/, table(%{
     | name=django-psql-persistent |
   })
end

Given /^I wait until #{QUOTED} report for #{QUOTED} namespace to be available$/ do | report_type, namespace |
  # longest wait time is 8 minutes
  seconds = 8 * 60  # for PVs it can take as long as 5 minutes sometimes more with timing of the query/creation
  res = []
  success = wait_for(seconds) do
    step %Q/I get the "#{report_type}" report and store it in the clipboard using:/, table(%{
       | query_type          | persistentvolumeclaim-request |
    })
    res = cb.report.select { |r| r['namespace'] == namespace }
    res.count > 0
  end
  if res.count == 0
    raise "report '#{report_type}' for project '#{namespace}' not found after #{seconds} seconds"
  end
end

Given /^I enable route for#{OPT_QUOTED} metering service$/ do | metering_name |
  metering_name ||= "openshift-metering"
  htpasswd = BushSlicer::SSL.sha1_htpasswd(username: user.name, password: user.password)
  cookie_seed = rand_str(32, :hex)
  route_yaml = <<BASE_TEMPLATE
    apiVersion: metering.openshift.io/v1alpha1
    kind: Metering
    metadata:
      name: "#{metering_name}"
    spec:
      reporting-operator:
        spec:
          route:
            enabled: true
        authProxy:
          enabled: true
        htpasswdData: |
          #{htpasswd}
        cookieSeed: "#{cookie_seed}"
        subjectAccessReviewEnabled: true
        delegateURLsEnabled: true
BASE_TEMPLATE
  logger.info("### Updating metering service with route enabled\n #{route_yaml}")
  @result = user.cli_exec(:apply, f: "-", _stdin: route_yaml)
  # route name is ALWAYS set to 'metering'
  step %Q/I wait for the "metering" route to appear up to 120 seconds/
end

# XXX: should we check metering route exists first prior to patching?
Given /^I disable route for#{OPT_QUOTED} metering service$/ do | metering_name |
  metering_name ||= "openshift-metering"
  patch_json = '{"spec":{"reporting-operator":{"spec":{"route":{"enabled":false}}}}}'
  opts = {resource: 'metering', resource_name: metering_name, p: patch_json, type: 'merge'}
  @result = user.cli_exec(:patch, **opts)
  # route name is ALWAYS set to 'metering'
  step %Q/I wait for the resource "route" named "metering" to disappear/
end

# use the hack/openshift-install.sh shell script to install metering.  NOTE, metering
# for shell-script installation, the default namespace is 'metering' which differs
# from ansible install.  We set the cb['metering_namespace'] to it.
Given /^metering service is (installed|uninstalled) using shell script$/ do | op |
  step %Q/I use the first master host/
  metering_repo='https://github.com/operator-framework/operator-metering.git'
  # install git
  install_git_via_yum = "yum -y install git"
  host.exec(install_git_via_yum)
  git_clone_cmd = "git clone #{metering_repo}"
  res = host.exec(git_clone_cmd)
  cb[:metering_namespace] = 'metering'
  if op == 'installed'
    shell_cmd = "./operator-metering/hack/openshift-install.sh"
  else
    shell_cmd = "./operator-metering/hack/openshift-uninstall.sh"
  end
  res = host.exec(shell_cmd)
  raise "#{cb.metering_namespace} #{op} unsuccessfully" unless res[:success]
end
