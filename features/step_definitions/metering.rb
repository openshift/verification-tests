# helper step for metering scenarios
require 'ssl'
# For metering automation, we just install once and re-use the installation
# unless the scenarios are for testing installation
# checks that metering service is already installed
Given /^metering service has been installed successfully(?: using (ansible|shell script|OLM))?$/ do |method|
  ensure_admin_tagged
  namespace = "openshift-metering"  # set it as default
  # first check if metering service exists, skip installation if already there
  step %Q/I save the project hosting "metering" resource to "metering_namespace" clipboard/
  unless cb.metering_namespace
    # default to OLM install
    method ||= "OLM"
    case method
    when "shell script"
      namespace = "metering"
      metering_name = "operator-metering"
    when "ansible"
      namespace = "openshift-metering"
      metering_name = "openshift-metering"
    when "OLM"
      namespace = "openshift-metering"
      metering_name = "operator-metering"
    end
    # a pre-req is that openshift-monitoring is installed in the system, w/o it
    # the openshift-metering won't function correctly
    unless project('openshift-monitoring').exists?
      raise "service openshift-monitoring is a pre-requisite for #{namespace}"
    end
  else
    @result = admin.cli_exec(:get, namespace: cb.metering_namespace.name, resource: 'metering', o: 'yaml')
    metering_name = @result[:parsed]['items'].first['metadata']['name']
  end

  # change project context
  unless cb.metering_namespace
    case method
    when "shell script"
      step %Q/metering service is installed using shell script/
    when "ansible"
      # install metering using default
      step %Q/default metering service is installed without cleanup/
    when "OLM"
      step %Q/the metering service is installed using OLM/
    end
    cb.metering_namespace = project(namespace)
  end
  step %Q/all metering related pods are running in the "#{cb.metering_namespace.name}" project/
  step %Q/I wait for the "#{metering_name}" metering to appear/
  # added check for datasource to make sure promethues imports are working
  step %Q/all reportdatasources are importing from Prometheus/
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
# for easier to test, we default to 'runImmediately', to disable that parameter,
# specify the parameter `run_immediately` the value `false` in the table
Given /^I get the #{QUOTED} report and store it in the#{OPT_SYM} clipboard using:$/ do |name, cb_name, table|
  ensure_admin_tagged

  cb_name ||= :report
  opts = opts_array_to_hash(table.raw)
  # one day before current time
  default_start_time = (Time.now - 86400).utc.strftime('%FT%TZ')
  default_end_time = "#{Time.now.year}" + "-12-30T23:59:59Z"  # end of the year
  default_format = 'json'
  opts[:run_immediately] ||= true
  # sanity check
  required_params = [:query_type ]
  required_params.each do |param|
    raise "Missing parameter '#{param}'" unless opts[param]
  end
  opts[:start_time] ||= default_start_time
  opts[:end_time] ||= default_end_time
  opts[:run_immediately] = to_bool(opts[:run_immediately])
  opts[:grace_period] ||= nil
  opts[:schedule] ||= opts[:schedule]
  opts[:format] ||= default_format
  opts[:metadata_name] ||= name
  unless opts[:use_existing_report] == 'true'
    # create the report resource
    opts[:report_yaml] = BushSlicer::Report.generate_yaml(opts)
    logger.info("#### generated report using the following yaml:\n #{opts[:report_yaml]}")
    report(name).construct(user: user, **opts)
    if opts[:run_immediately]
      report(name).wait_till_finished(user: user)
    else
      report(name).wait_till_running(user: user)
    end
  end

  step %Q/I perform the GET metering rest request with:/, table(%{
      | report_name | #{name} |
    })
  if opts[:format] != 'json' and opts[:format] != 'yaml'
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
       | query_type | #{report_type} |
    })
    res = cb.report.select { |r| r['namespace'] == namespace }
    res.count > 0
  end
  if res.count == 0
    raise "report '#{report_type}' for project '#{namespace}' not found after #{seconds} seconds"
  end
end

Given /^I enable route for#{OPT_QUOTED} metering service$/ do | metering_name |
  metering_name ||= metering.name
  # create the route only if one does not exists (currently it's hardcoded
  # in the chart file charts/reporting-operator/values.yaml)
  unless route('metering', cb.metering_namespace).exists?
    org_user = user
    step %Q/I switch to cluster admin pseudo user/
    htpasswd = BushSlicer::SSL.sha1_htpasswd(username: 'fake_user', password: 'fake_password')
    #htpasswd = BushSlicer::SSL.sha1_htpasswd(username: user.name, password: user.password)
    cookie_seed = rand_str(32, :hex)
    route_yaml = <<BASE_TEMPLATE
      apiVersion: metering.openshift.io/v1alpha1
      kind: Metering
      metadata:
        name: "#{metering.name}"
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
    @result = user.cli_exec(:apply, f: "-", _stdin: route_yaml, n: project.name)
    # route name is ALWAYS set to 'metering'
    step %Q/I wait for the "metering" route to appear up to 600 seconds/
    # switch back to original user
    @user = org_user if org_user
  end
  step %Q/I wait for metering route to be accessible/
end

# XXX: should we check metering route exists first prior to patching?
Given /^I disable route for#{OPT_QUOTED} metering service$/ do | metering_name |
  metering_name ||= cb.metering_namespace.name
  patch_json = '{"spec":{"reporting-operator":{"spec":{"route":{"enabled":false}}}}}'
  opts = {resource: 'metering', resource_name: metering_name, p: patch_json, type: 'merge', n: project.name}
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

# install metering via OLM,
Given /^the#{OPT_QUOTED} metering service is installed(?: to $QUOTED)? using OLM$/ do | metering_ns |
  ensure_admin_tagged
  ensure_destructive_tagged

  # 1. create the metering namespace
  metering_ns ||= "openshift-metering"
  project(metering_ns)
  step %Q/I switch to cluster admin pseudo user/
  @result = user.cli_exec(:create_namespace, name: metering_ns)
  # prep for OLM need to define configs via YAML
  # 1. metering-catalogsourceconfig.yaml
  catalog_source_config = "https://raw.githubusercontent.com/operator-framework/operator-metering/master/manifests/deploy/openshift/olm/metering.catalogsourceconfig.yaml"
  # 2. metering-operatorgroup.yaml
  operator_group = "https://raw.githubusercontent.com/operator-framework/operator-metering/master/manifests/deploy/openshift/olm/metering.operatorgroup.yaml"
  # 3. metering-subscription.yaml
  subscription = "https://raw.githubusercontent.com/operator-framework/operator-metering/master/manifests/deploy/openshift/olm/metering.subscription.yaml"
  metering_crd = "https://raw.githubusercontent.com/operator-framework/operator-metering/master/manifests/metering-config/default.yaml"

  # should really get the namespace dynamically
  @result = user.cli_exec(:apply, f: catalog_source_config, n: 'openshift-marketplace')
  @result = user.cli_exec(:apply, f: operator_group, n: project.name)
  @result = user.cli_exec(:apply, f: subscription, n: project.name)
  # wait for initial metering pod to become running first and then apply CRD
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=metering-operator |
  })

  @result = user.cli_exec(:apply, f: metering_crd, n: project.name)
  raise "OLM install of metering failed" unless @result[:success]
end

# XXX: currently OLM uninstall is TBD, we uninstall by removing the namespace
Given /^the#{OPT_QUOTED} metering service is uninstalled using OLM$/ do | metering_ns |
  ensure_admin_tagged
  ensure_destructive_tagged
  metering_ns ||= "openshift-metering"
  step %Q/I switch to cluster admin pseudo user/ unless env.is_admin? user
  project(metering_ns)
  # step %Q/I use the "#{metering_ns}" project/ unless project.name == metering_ns
  step %Q/I ensure "#{metering_ns}" project is deleted/
  project("openshift-marketplace")
  step %Q/I ensure "metering-operators" catalogsourceconfig is deleted/
end

Given /^all reportdatasources are importing from Prometheus$/ do
  project ||= project(cb.metering_namespace.name)
  data_sources  = BushSlicer::ReportDataSource.list(user: user, project: project)
  # ignore reportdatasource that ends with `-raw`
  dlist = data_sources.select{ |d| d.prometheus_metrics_importer_query}
  seconds = 240   # after initial installation it takes about 2-3 minutes to initiate Prometheus sync
  success = wait_for(seconds) {
    dlist.all? { |ds| report_data_source(ds.name).last_import_time(cached: false) }
  }
  raise "Querying for reportdatasources returned failure, probabaly due to Prometheus import failed" unless success
end

# get the report using exposed API endpoint instead of doing it from the node
# we need the following to build the REST URL
# 1. METERING_REPORT_API_ROUTE: expoed route for metering
# 2. METERING_NAMESPACE: the namespace under which metering is installed
# 3. REPORT_NAME: the specific name of the report we are querying
When /^I perform the GET metering rest request with:$/ do | table |
  opts = opts_array_to_hash(table.raw)
  bearer_token = opts[:token] ? opts[:token] : service_account('reporting-operator').load_bearer_tokens.first.token
  https_opts = {}
  https_opts[:headers] ||= {}
  https_opts[:headers][:accept] ||= "application/json"
  https_opts[:headers][:content_type] ||= "application/json"
  https_opts[:headers][:authorization] ||= "Bearer #{bearer_token}"
  # first we need to expose reporting API route if not route is found
  step %Q/I enable route for metering service/ unless route('metering').exists?
  report_name = opts[:report_name]
  url_path ||= opts[:custom_url]
  url_path ||= "/api/v1/reports/get?name=#{report_name}&namespace=#{cb.metering_namespace.name}&format=json"

  report_query_url = route.dns + url_path
  @result = BushSlicer::Http.request(url: report_query_url, **https_opts, method: 'GET')
  if @result[:success]
    @result[:parsed] = YAML.load(@result[:response])
  end
end

Given /^I wait(?: up to ([0-9]+) seconds)? for metering route to be accessible$/ do | seconds |
  seconds = seconds.to_i unless seconds.nil?
  seconds ||= 120
  wait_for(seconds) {
    step %Q/I perform the GET metering rest request with:/, table(%{
      | custom_url | /healthy |
    })
    @result[:success]
  }
  raise "Metering route did not become accessible within #{seconds} seconds" unless @result[:success]
end
