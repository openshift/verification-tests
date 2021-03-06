require 'openshift/route'
require 'openshift/service'

# e.g I expose the "myapp" service
When /^I expose(?: the#{OPT_QUOTED} port of)? the#{OPT_QUOTED} service$/ do |port, service_name|
  transform binding, :port, :service_name
  cache_resources service(service_name).expose(user: user, port: port)

  # for backward compatibility return a successrul ResultHash
  @result = {
    success: true,
    instruction: "expose service by creating a route",
    response: "",
    exitstatus: 0
  }
end

# get the route information given a project name
Given /^(I|admin) save the hostname of route #{QUOTED} in project #{QUOTED} to the#{OPT_SYM} clipboard$/ do |by, route_name, proj_name, clipboard_name |
  transform binding, :by, :route_name, :proj_name, :clipboard_name
  _user = by == "admin" ? admin : user
  ensure_admin_tagged if by == "admin"
  clipboard_name ||= :host_route
  cb_name = clipboard_name.to_sym
  res = _user.cli_exec(:get, resource: 'route', n: proj_name, o: 'yaml')
  if res[:success]
    res[:parsed]['items'].each do | route |
      cb[cb_name] = route['spec']['host'] if route['metadata']['name'] == route_name
    end
  end
  raise "There is no route named '#{route_name}' in project '#{proj_name}'" if cb[cb_name].nil?
end

# add required cluster role (based on master version) to router service account for ingress object
Given /^required cluster roles are added to router service account for ingress$/ do
  step 'cluster role "cluster-reader" is added to the "system:serviceaccount:default:router" service account'
  if env.version_lt("3.6", user: user)
    step 'cluster role "system:service-serving-cert-controller" is added to the "system:serviceaccount:default:router" service account'
  else
    step 'cluster role "system:openshift:controller:service-serving-cert-controller" is added to the "system:serviceaccount:default:router" service account'
  end
end

# add env to dc/router and wait for new router pod ready
Given /^admin ensures new router pod becomes ready after following env added:$/ do |table|
  transform binding, :table
  ensure_admin_tagged
  ensure_destructive_tagged
  begin
    org_user = @user
    step %Q/I switch to cluster admin pseudo user/
    step %Q/I use the "default" project/
    step %Q/default router deployment config is restored after scenario/
    step %Q/all existing pods are ready with labels:/, table(%{
      | deploymentconfig=router |
    })
    step %Q/I run the :set_env client command with:/, table([
      ["namespace", "default" ],
      ["resource", "dc/router" ],
      *table.raw.map {|e| ["e", e[0]] }
    ])
    step %Q/the step should succeed/
    step %Q/all existing pods die with labels:/, table(%{
      | deployment=router-<%= cb.router_golden_version %> |
    })
    step %Q/a pod becomes ready with labels:/, table(%{
      | deploymentconfig=router |
    })
    @user = org_user
  end
end

Given /^admin ensures a F5 router pod is ready$/ do
  ensure_admin_tagged

  org_user = @user
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "default" project/
  step %Q/a pod becomes ready with labels:/, table(%{
      | deploymentconfig=f5router |
  })
  @user = org_user
end

Given /^F5 router public IP is stored in the :vserver_ip clipboard$/ do
  steps """
    Given I use the first master host
    When I run commands on the host:
      | cat /root/f5-vip.conf |
    Then the step should succeed
    And evaluation of `@result[:response].chomp` is stored in the :vserver_ip clipboard
  """
end

Given /^default router image is stored into the#{OPT_SYM} clipboard$/ do | cb_name |
  transform binding, :cb_name
  step %Q/I run the :get admin command with:/, table(%{
    | resource      | dc      |
    | resource_name | router  |
    | namespace     | default |
    | template      | {{(index .spec.template.spec.containers 0).image}} |
  })
  step %Q/the step should succeed/
  cb[cb_name] = @result[:response]
end

Given /^the last reload log of a router pod is stored in #{SYM} clipboard$/ do | cb_name |
  transform binding, :cb_name
  unless cb.router_pod
    step %Q/a pod becomes ready with labels:/, table(%{
      | deploymentconfig=router |
    })
    step %Q/evaluation of `pod.name` is stored in the :router_pod clipboard/
  end

  res = admin.cli_exec(:logs, resource_name: cb.router_pod, n: 'default')
  cb[cb_name] = res[:response].scan(/^I\d+.*Router reloaded:$/).last
  logger.info "The last reloaded log with timestamp is: #{cb[cb_name]}."
end

Given /^I use the router project$/ do
  if env.version_ge("4.0", user: user)
    step %Q/I use the "openshift-ingress" project/
  else
    step %Q/I use the "default" project/
  end
end

Given /^all default router pods become ready$/ do
  if env.version_ge("4.0", user: user)
    label_filter = "ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default"
  else
    label_filter = "deploymentconfig=router"
  end
    step %Q/all existing pods are ready with labels:/, table(%{
      | #{label_filter} |
    })
end

Given /^I store an available router IP in the#{OPT_SYM} clipboard$/ do |cb_name|
  transform binding, :cb_name
  step %Q/I run the :create client command with:/, table(%{
    | f |  #{BushSlicer::HOME}/testdata/networking/service_with_selector.json |
  })
  step %Q/I expose the "selector-service" service/
  step %Q/I have a pod-for-ping in the project/
  step %Q/I execute on the pod:/, table(%{
    | bash | -c | curl http://<%= route("selector-service", service("selector-service")).dns(by: user) %>/ --connect-timeout 10 -I -v -s |
  })

  cb[cb_name] = @result[:response].match(/Connected to .* \((\d+.\d+.\d+.\d+)\)/).captures
  raise "Cannot find an available router IP" if cb[cb_name].nil?
  logger.info cb[cb_name]

  step %Q/I delete all resources from the project/
end
