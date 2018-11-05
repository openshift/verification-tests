# helper step for metering scenarios

# For metering automation, we just install once and re-use the installation
# unless the scenarios are for testing installation

# checks that metering service is already installed
Given /^metering service has been installed successfully$/ do
  ensure_admin_tagged
  # a pre-req is that openshift-monitoring is installed in the system, w/o it
  # the openshift-metering won't function correctly
  unless project('openshift-monitoring').exists?
    raise "service openshift-monitoring is a pre-requisite for openshift-metering"
  end
  # change project context
  unless project('openshift-metering').exists?
    # install metering using deault
    step %Q/default metering service is installed without cleanup/
  else
    step %Q/all metering related pods are running in the project/
  end
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
