# helper step for metering scenarios
require 'ssl'

# For metering automation, we just install once and re-use the installation
# unless the scenarios are for testing installation
# checks that metering service is already installed
# OLM   => ./bin/deploy-metering
# OperatorHub => Openshift Webconsole  <<  default method
Given /^metering service has been installed successfully(?: using (OLM|OperatorHub))?$/ do |method|
  ensure_admin_tagged
  method ||= 'OperatorHub'
  namespace = "openshift-metering"  # set it as default
  step %Q/I switch to cluster admin pseudo user/
  user.cli_exec(:create_namespace, name: namespace)
  # NOTE: we need to change project context as admin
  step %Q/I use the "#{namespace}" project/
  cb[:metering_resource_type] = "meteringconfig"
  cb[:metering_namespace] = project(namespace)
  unless metering_config('openshift-metering').exists?
    # default to OLM install
    method ||= "OperatorHub"
    case method
    when "OperatorHub", "OLM"
      namespace = "openshift-metering"
      metering_name = "operator-metering"
    end
    # a pre-req is that openshift-monitoring is installed in the system, w/o it
    # the openshift-metering won't function correctly
    unless project('openshift-monitoring').exists?
      raise "service openshift-monitoring is a pre-requisite for #{namespace}"
    end
  else
    metering_name = metering_config.raw_resource['metadata']['name']
  end

  # change project context
  unless metering_config(namespace).exists?
    case method
    when "OLM", "OperatorHub"
      step %Q/the metering service is installed using OLM/
    end
  end
  step %Q/all metering related pods are running in the "#{cb.metering_namespace.name}" project/
  step %Q/I wait for the "#{metering_name}" #{cb.metering_resource_type} to appear/
  # added check for datasource to make sure promethues imports are working
  step %Q/all reportdatasources are importing from Prometheus/
end

Given /^default metering service is installed without cleanup$/ do
  step %Q/I create a project with non-leading digit name/
  step %Q/I store master major version in the clipboard/
  step %Q/metering service is installed with ansible using:/, table(%{
    | inventory     | #{ENV['BUSHSLICER_HOME']}/testdata/logging_metrics/default_install_metering_params |
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

Given /^I construct a patch_json with s3 enabled and save it to the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :patch_json
  htpasswd = BushSlicer::SSL.sha1_htpasswd(username: 'fake_user', password: 'fake_password')
  cookie_seed = rand_str(32, :hex)
  patch_json = <<BASE_TEMPLATE
{
   "spec": {
      "reporting-operator": {
         "spec": {
            "authProxy": {
               "cookieSeed": "#{cookie_seed}",
               "delegateURLsEnabled": true,
               "enabled": true,
               "htpasswdData": "#{htpasswd}",
               "subjectAccessReviewEnabled": true
            },
            "route": {
               "enabled": true
            }
         }
      }
   }
}
BASE_TEMPLATE
  cb[cb_name] = patch_json
end

Given /^I enable route for#{OPT_QUOTED} metering service$/ do | metering_name |
  metering_name ||= metering_config('operator-metering').name
  # create the route only if one does not exists (currently it's hardcoded
  # in the chart file charts/reporting-operator/values.yaml)
  unless route('metering').exists?
    org_user = user
    ### XXX: TODO until 4.2 is GAed,
    if operator_group('metering-operators').exists?
      cb[:metering_resource_type] = 'meteringconfig'
    else
      cb[:metering_resource_type] = 'metering'
    end
    step %Q/I switch to cluster admin pseudo user/
    step %Q/I construct a patch_json with s3 enabled and save it to the clipboard/
    logger.info("### Updating metering service with route enabled\n #{cb.patch_json}")
    opts = {resource: cb.metering_resource_type, resource_name: metering_name, p: cb.patch_json, type: 'merge', n: project.name}
    @result = user.cli_exec(:patch, **opts)
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


# install metering via OLM (via OperatorHub)
Given /^the metering service is installed(?: to #{OPT_QUOTED})? using OLM$/ do | metering_ns |
  ensure_admin_tagged
  ensure_destructive_tagged
  # 1. create the metering namespace
  metering_ns ||= "openshift-metering"
  step %Q/I switch to cluster admin pseudo user/
  @result = user.cli_exec(:create_namespace, name: metering_ns)
  step %Q(I set operator channel)
  cb['metering_namespace'] = project(metering_ns)
  step %Q(the first user is cluster-admin)
  step %Q(I switch to the first user)
  step %Q(I open admin console in a browser)
  step %Q/I perform the :goto_operator_subscription_page web action with:/, table(%{
    | package_name     | metering-ocp        |
    | catalog_name     | qe-app-registry     |
    | target_namespace | <%= project.name %> |
  })
  step %Q/I perform the :set_custom_channel_and_subscribe web action with:/, table(%{
    | update_channel    | <%= cb.channel %> |
    | install_mode      | OwnNamespace      |
    | approval_strategy | Automatic         |
  })
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=metering-operator |
  })
  step %Q(I run oc create as admin over ERB test file: metering/configs/meteringconfig_hdfs.yaml)
  step %Q/all metering related pods are running in the project/
  step %Q/all reportdatasources are importing from Prometheus/
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
  # valid reportdatasources are those with a prometheusMetricsImporter query statement
  dlist = data_sources.select{ |d| d.prometheus_metrics_importer_query}
  seconds = 600   # after initial installation it takes about 2-3 minutes to initiate Prometheus sync
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
  https_opts[:proxy] = env.client_proxy if env.client_proxy
  # first we need to expose reporting API route if not route is found
  step %Q/I enable route for metering service/ unless route('metering').exists?
  report_name = opts[:report_name]
  opts[:api_version] ||= 'v2'
  url_path ||= opts[:custom_url]
  # v2
  if opts[:api_version] == 'v2'
    url_path ||= "/api/v2/reports/#{cb.metering_namespace.name}/#{report_name}/table?format=json"
  else
    # v1
    url_path ||= "/api/v1/reports/get?name=#{report_name}&namespace=#{cb.metering_namespace.name}&format=json"
  end

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
## valid column names are EARLIEST METRIC, NEWEST METRIC, IMPORT START, IMPORT END, LAST IMPORT TIME
And /^I get the (latest|earliest) timestamp from reportdatasource column #{QUOTED} and store it to#{OPT_SYM} clipboard$/ do | time_filter, column, cb_name |
  ensure_admin_tagged
  cb_name ||= :rds_timestamp
  column_lookup = {
    "EARLIEST METRIC"  => "earliestImportedMetricTime",
    "NEWEST METRIC,"   => "newestImportedMetricTime",
    "IMPORT START"     => "importDataStartTime",
    "IMPORT END"       => "importDataEndTime",
    "LAST IMPORT TIME" => "lastImportTime"
  }
  column_filter = column_lookup[column]
  @result = admin.cli_exec(:get, resource: 'reportdatasource', o: 'yaml')
  # filter out to use only non-raw ending
  res = @result[:parsed]['items'].map { |i| i.dig('status', 'prometheusMetricsImportStatus', column_filter) }.compact
  cb[cb_name] = time_filter == 'lastest'? res.max : res.min
end

# for flexiblity the order of precedence is
#   1. ENV
#   2. table option
# valid options are feed into the report_hash Hash variable
#   report_hash = {
#         "apiVersion" => "metering.openshift.io/v1alpha1",
#         "kind" => 'Report',
#         "metadata" => {
#           "name" => opts[:metadata_name]
#         },
#         "spec" => {
#           "reportingStart" => opts[:start_time],
#           "reportingEnd" => opts[:end_time],
#           "query" => opts[:query_type],
#           "gracePeriod" => opts[:grace_period],
#           "runImmediately" => opts[:run_immediately],
#           "schedule" => schedule
#         },
#
When /^I generate a metering report with:$/ do |table|
  opts = opts_array_to_hash(table.raw)
  ### these are defaults
  # 1. runImmediately=true unless schedule (period)is specified
  # And I get the latest timestamp from reportdatasource column "EARLIEST METRIC" and store it to clipboard
  opts[:query_type] ||= ENV['METERING_QUERY_TYPE']
  raise "User must specify a query type " unless opts[:query_type]
  opts[:period] ||= ENV['METERING_PERIOD']
  opts[:expression] ||= ENV['METERING_CRON_EXPRESSION']
  opts[:grace_period] ||= ENV['METREING_GRACE_PERIOD']
  step %Q/I get the latest timestamp from reportdatasource column "EARLIEST METRIC" and store it to clipboard/
  opts[:start_time] ||= cb.rds_timestamp
  opts[:end_time] ||= "#{Time.now.year}" + "-12-30T23:59:59Z"  # end of the year
  opts[:run_immediately] ||= opts[:period] ? nil : true
  # just use the query + period or run_immediately
  unless opts[:metadata_name]
    # runImmediately, just attach 'now' to the end
    suffix = opts[:period] ? opts[:period] : "now"
    opts[:metadata_name] = opts[:query_type] + "-" + suffix
  end
  name = opts[:metadata_name]
  opts[:report_yaml] = BushSlicer::Report.generate_yaml(opts)
  logger.info("#### generated report using the following yaml:\n #{opts[:report_yaml]}")
  report(name).construct(user: user, **opts)
  if opts[:run_immediately]
    report(name).wait_till_finished(user: user)
  else
    report(name).wait_till_running(user: user)
  end
end

# verify all metering pods are in the RUNNING state
# expected pods are listed here:
# https://raw.githubusercontent.com/openshift-qe/output_references/master/metering/pod_labels.out
# the longest chain of deps is metering -> presto -> hive & storage (hdfs, s3, nooba, etc.)
# so metering can't be ready until presto is ready
# presto can't be ready until hive is ready
# and metering can't be ready until presto can write to storage.
#
Given /^all metering related pods are running in the#{OPT_QUOTED} project$/ do | proj_name |
  ensure_destructive_tagged
  target_proj = proj_name.nil? ? "openshift-metering" : proj_name
  step %Q/I switch to cluster admin pseudo user/
  project(target_proj)
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=metering-operator |
  })

  if metering_config('openshift-metering').hive_type == 'hdfs'
    step %Q/a pod becomes ready with labels:/, table(%{
      | hdfs=datanode,statefulset.kubernetes.io/pod-name=hdfs-datanode-0 |
    })
    step %Q/a pod becomes ready with labels:/, table(%{
      | hdfs=datanode,statefulset.kubernetes.io/pod-name=hdfs-datanode-1 |
    })
    step %Q/a pod becomes ready with labels:/, table(%{
      | hdfs=datanode,statefulset.kubernetes.io/pod-name=hdfs-datanode-2 |
    })
  end

  step %Q/a pod becomes ready with labels:/, table(%{
    | hive=metastore,statefulset.kubernetes.io/pod-name=hive-metastore-0 |
  })

  step %Q/a pod becomes ready with labels:/, table(%{
    | hive=server,statefulset.kubernetes.io/pod-name=hive-server-0 |
  })

  step %Q/a pod becomes ready with labels:/, table(%{
    | app=presto |
  })
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=reporting-operator |
  })

end

# allow user to override the operator channel by setting clipboard cb.channel
# @return cb.channel set by priority
# 1. in the step  2. environment OPERATOR_CHANNEL
# 3. cluster_version('version')
And /^I set operator channel(?: to#{OPT_QUOTED})?$/ do | channel |
  if channel
    cb.channel = channel
  elsif ENV['OPERATOR_CHANNEL']
    cb.channel = ENV['OPERATOR_CHANNEL']
  else
    cb.channel = cluster_version('version').version.split('-').first.to_f
  end
  logger.info("Using operator channel: #{cb.channel}")
end

