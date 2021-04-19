# This step will clean all the layers in the default registry
#Given /^all the image layers are deleted in the internal registry$/ do
#  ensure_admin_tagged
#  org_proj_name = project.name
#  org_user = @user
#  _regdir =  cb["reg_dir"]
#  _regdir = "/registry" unless _regdir
#  begin
#    step %Q/I switch to cluster admin pseudo user/
#    step %Q/I use the "default" project/
#    step %Q/a pod becomes ready with labels:/, table(%{
#        | deploymentconfig=docker-registry |
#    })
#    step %Q/I execute on the pod:/,table([["bash","-c","rm -rf #{_regdir}/docker/registry/v2/blobs/*"]])
#    step %Q/the step should succeed/
#  ensure
#    @user = org_user
#    project(org_proj_name)
#  end
#end

Given /^I change the internal registry pod to use a new emptyDir volume$/ do
  ensure_destructive_tagged
  cb["reg_dir"] = "/registrytmp"
  begin
    step %Q/I run the :set_volume admin command with:/, table(%{
      | resource   | dc/docker-registry |
      | add        | true               |
      | mount-path | /registrytmp       |
      | type       | emptyDir           |
      | namespace  | default            |
    })
    step %Q/the step should succeed/
    step %Q/I wait until the latest rc of internal registry is ready/
    step %Q/I run the :env admin command with:/, table(%{
      | resource  | dc/docker-registry                                     |
      | e         | REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registrytmp |
      | e         | REGISTRY_CONFIGURATION_PATH=/config.yml                |
      | namespace | default                                                |
    })
    step %Q/the step should succeed/
    step %Q/I wait until the latest rc of internal registry is ready/
  end
end

Given /^I wait until the latest rc of internal registry is ready$/ do
  ensure_admin_tagged
  _rc = BushSlicer::ReplicationController.get_labeled(
    "docker-registry",
    user: admin,
    project: project("default", switch: false)
  ).max_by {|rc| rc.created_at}
  raise "no matching registry rcs found" unless _rc
  @result = _rc.wait_till_ready(admin, 900)
  raise "#{rc_name} didn't become ready" unless @result[:success]
end

Given /^all the image layers in the#{OPT_SYM} clipboard do( not)? exist in the registry$/ do |layers_board,not_exist|
  _regdir =  cb["reg_dir"]
  _regdir = "/registry" unless _regdir
  layers = cb[layers_board]
  ensure_admin_tagged
  org_proj_name = project.name
  org_user = @user
  if not_exist
    expect_layer_no =0
    err_msg = "exist"
  else
    expect_layer_no = 1
    err_msg = "do not exist"
  end
  begin
    step %Q/I switch to cluster admin pseudo user/
    step %Q/I use the "openshift-image-registry" project/
    step %Q/a pod becomes ready with labels:/, table(%{
        | docker-registry=default |
    })
    layers.each { | layer|
      id =  layer.dig("name").split(':')[1]
      step %Q/I execute on the pod:/,table([["bash","-c","find #{_regdir}/docker/registry/v2/blobs/ |grep #{id} |grep -v data | wc -l"]])
      step %Q/the step should succeed/
      layer_no = @result[:response].strip.to_i
      unless layer_no == expect_layer_no
        raise "ImageStreamTag layer : #{id} #{err_msg} on the registry pod"
      end
    }
  ensure
    @user = org_user
    project(org_proj_name)
  end
end

Given /^I add the insecure registry to docker config on the node$/ do
  ensure_destructive_tagged
  raise "You need to create a insecure private docker registry first!" unless cb.reg_svc_url
  _node = node

  step 'the node service is verified'
  step 'the node service is restarted on the host after scenario'
  teardown_add {
    err_msg = "The docker service failed to restart and is not active"
    @result = _node.host.exec_admin("systemctl restart docker")
    raise err_msg unless @result[:success]
    sleep 3
    @result = _node.host.exec_admin("systemctl is-active docker")
    raise err_msg unless @result[:success]
  }
  step 'the "/etc/sysconfig/docker" file is restored on host after scenario'
  step 'I run commands on the host:', table(%{
      | sed -i '/^INSECURE_REGISTRY*/d' /etc/sysconfig/docker |
  })
  step 'the step should succeed'
  step 'I run commands on the host:', table(%{
      | echo "INSECURE_REGISTRY='--insecure-registry <%= cb.reg_svc_url%>'" >> /etc/sysconfig/docker |
   })
  step 'the step should succeed'
  step "I run commands on the host:", table(%{
      | systemctl restart docker |
  })
  step "the step should succeed"
  step 'I wait for the "<%= cb.reg_svc_name %>" service to become ready'
end

Given /^I docker push on the node to the registry the following images:$/ do |table|
  ensure_admin_tagged
  table.raw.each do |image|
    step 'I run commands on the host:', table(%Q{
        | docker pull #{ image[0] } |
                                              })
    step 'I run commands on the host:', table(%Q{
        | docker tag #{ image[0] } #{ cb.reg_svc_url }/#{ image[1] } |
                                              })
    step 'I run commands on the host:', table(%Q{
        | docker push #{ cb.reg_svc_url }/#{ image[1] } |})
  end
end

Given /^I log into auth registry on the node$/ do
  ensure_admin_tagged
  step 'I run commands on the host:', table(%{
        | docker login -u <%= cb.reg_user %> -p <%= cb.reg_pass %> <%= cb.reg_svc_url %> |
  })
  step 'the step should succeed'
end

#TODO: better random name generator
Given /^I obtain default registry IP HOSTNAME by a dummy build in the project$/ do
  #generate a dummy image
  dummy_image = "dummy-image-" + rand(999999).to_s
  step %Q/I run the :new_app client command with:/, table(%{
      | app_repo | centos/ruby-22-centos7~https://github.com/sclorg/ruby-ex.git |
      | name     | #{dummy_image}                                                  |
      })
  step 'the step should succeed'

  #copy registry ip to clipboard
  cb[:int_reg_ip] = image_stream(dummy_image).docker_registry_ip_or_hostname(user: user)

  #clean up dummy image
  step %Q/I run the :delete client command with:/, table(%{
      | object_type       | is               |
      | object_name_or_id | #{dummy_image}   |
      | object_name_or_id | ruby-22-centos7  |
      })
  step 'the step should succeed'
  step %Q/I run the :delete client command with:/, table(%{
      | object_type       | buildconfig    |
      | object_name_or_id | #{dummy_image} |
      })
  step 'the step should succeed'
  step %Q/I run the :delete client command with:/, table(%{
      | object_type       | deploymentconfig |
      | object_name_or_id | #{dummy_image}   |
      })
  step 'the step should succeed'
  step %Q/I run the :delete client command with:/, table(%{
      | object_type       | service        |
      | object_name_or_id | #{dummy_image} |
      })
  step 'the step should succeed'
end

Given /^default docker-registry dc is deleted$/ do
  _admin = admin

  _dc = dc("docker-registry", project("default", switch: false))
  @result = _dc.get_checked(user: _admin)
  step %Q/I save the output to file> dc.yaml/
  _dc.ensure_deleted(user: admin)
  _svc = service("docker-registry", project("default", switch: false))

  teardown_add {
    # we need to check registry service exists before we create dc
    # if the default docker registry service does not exist it will raise an error
    # if we didnt do that the pod will be created but will be missing
    # necessary env vars. It will then respond with HTTP error 500 on push.
    #
    # more on this: https://github.com/openshift/origin/issues/10585#issuecomment-279696070
    #
    raise "The default docker registry service needs to exist before running this step." unless _svc.exists?(user: _admin)
    _dc.ensure_deleted(user: admin)
    @result = _admin.cli_exec(:create, f: "dc.yaml", n: "default")
    raise "The deployment config of the default docker registry was not restored!" unless @result[:success]
  }
end

Given /^default docker-registry service is deleted$/ do
  _admin = admin
  _svc = service("docker-registry", project("default", switch: false))
  @result = _svc.get_checked(user: _admin)
  step %Q/I save the output to file> svc.yaml/
  _svc.ensure_deleted(user: admin)
  teardown_add {
    _svc.ensure_deleted(user: admin)
    @result = _admin.cli_exec(:create, f: "svc.yaml", n: "default")
    raise "The service of the default docker registry was not restored!" unless @result[:success]
  }
end

 Given /^default registry is verified using a pod in a project( after scenario)?$/ do |after|
  p = proc {
    step %Q/I switch to the first user/
    step %Q/I create a new project/
    step %Q/I run the :new_app client command with:/, table(%{
      | app_repo | centos/ruby-22-centos7~https://github.com/sclorg/ruby-ex.git |
    })
    step %Q/the step should succeed/
    step %Q/I wait for the "ruby-ex" service to become ready/
    step %Q/the project is deleted/
  }

  if after
    teardown_add p
  else
    p.call
  end
end

Given /^I secure the default docker(?: (daemon set))? registry$/ do |deployment_type|
  _admin = admin
  _svc = service("docker-registry", project("default", switch: false))
  cb.default_reg_svc_ip = _svc.ip(user: _admin, cached: false)
  cb.default_reg_svc_port = _svc.ports(user: _admin, cached: false)[0]["port"]
  signer_path = "/etc/origin/master"
  _host = env.master_hosts[0]

  # remove the old tls certificates files if exists
  _host.exec_admin("rm -f registry.crt registry.key")
  step %Q/the step should succeed/

  _oadm_command = "oc adm"
  if env.version_lt("3.3", user: user)
    _oadm_command = "oadm"
  end

  _host.exec_admin(_oadm_command + " ca create-server-cert --signer-cert=#{signer_path}/ca.crt --signer-key=#{signer_path}/ca.key --signer-serial=#{signer_path}/ca.serial.txt --hostnames=#{cb.default_reg_svc_ip},docker-registry.default.svc.cluster.local,docker-registry.default.svc --cert=registry.crt --key=registry.key")
  step %Q/the step should succeed/

  registry_secret_name = "registry-secret-#{rand_str(5, :dns)}"
  registry_secret_mount = "/etc/secrets"

  _host.exec_admin("oc secret new #{registry_secret_name} registry.crt registry.key")
  step %Q/the step should succeed/

  _secret = secret(registry_secret_name, project("default", switch: false))

  teardown_add {
    _host.exec_admin("oc secret unlink sa/default #{registry_secret_name}")
    _secret.ensure_deleted(user: _admin)
  }

  _host.exec_admin("oc secret link sa/default #{registry_secret_name}")
  step %Q/the step should succeed/

  _deployment = ""
  if deployment_type
    _deployment = "ds"
  else
    _deployment = "dc"
  end

  step 'I run the :set_volume admin command with:', table(%{
      | resource    | #{_deployment}/docker-registry       |
      | add         | true                     |
      | type        | secret                   |
      | secret-name | #{registry_secret_name}  |
      | mount-path  | #{registry_secret_mount} |
  })
  step %Q/the step should succeed/
  step 'I run the :set_probe admin command with:', table(%{
      | resource  | #{_deployment}/docker-registry    |
      | liveness  | true                  |
      | readiness | secret                |
      | get_url   | https://:5000/healthz |
  })
  step %Q/the step should succeed/
  step 'I run the :env admin command with:', table(%{
      | resource    | #{_deployment}/docker-registry                                                  |
      | keyval      | REGISTRY_HTTP_TLS_CERTIFICATE=#{registry_secret_mount}/registry.crt |
      | keyval      | REGISTRY_HTTP_TLS_KEY=#{registry_secret_mount}/registry.key         |
  })
  step %Q/the step should succeed/
  # the pods are not automatically updated when the daemon set deployment is updated
  # we need to delete the pods, so they will get recreated with new config.
  if _deployment == "ds"
    step %Q/I run the :delete admin command with:/, table(%{
      | object_type | pods                    |
      | l           | docker-registry=default |
    })
    step %Q/the step should succeed/
    num_pods = daemon_set("docker-registry", project("default", switch: false)).desired_number_scheduled(user: admin)
    step %Q/#{num_pods} pods become ready with labels:/, table(%{
         | docker-registry=default |
    })
  else
  # waiting for all the pods to finish building and our final pod
  # to become available with label.
  # NOTE: If the system will react slower, there is a possibility
  # that the below step will catch the old pod as ready as it has the same labels
    step %Q/1 pod becomes ready with labels:/, table(%{
         | deploymentconfig=docker-registry |
    })
  end
  # need to wait few seconds until the registry is up and running
  # if a master service restart is done right after the pod is created
  # without this time interval kubelet will not be able to make a http
  # request to kubernetes, that its up and the pod will fail
  step %Q/20 seconds have passed/

end

Given /^default registry service ip is stored in the#{OPT_SYM} clipboard$/ do |cb_name|
  # save the orignial project name
  org_proj_name = project(generate: false).name rescue nil
  cb_name ||= :registry_ip
  # XXX: TODO verify which OCP version the dns name does not resolve 
  # Error response from daemon: Get https://docker-registry.default:5000/v1/users/: dial tcp: lookup docker-registry.default on 172.16.120.63:53: no such host
  if env.version_ge("4.0", user: user)
    cb[cb_name] = "image-registry.openshift-image-registry.svc:5000"
  elsif env.version_ge("3.10", user: user)
    cb[cb_name] = "docker-registry.default.svc:5000"
  else
    cb[cb_name] = service("docker-registry", project('default')).url(user: admin)
    project(org_proj_name) if org_proj_name
  end
end

Given /^default (docker-registry|registry-console) route is stored in the#{OPT_SYM} clipboard$/ do |route_name, cb_name|
  # save the orignial project name
  org_proj_name = project(generate: false).name rescue nil
  cb_name ||= :registry_route
  cb[cb_name] = route(route_name, service(route_name,project('default'))).dns(by: admin)
  project(org_proj_name) if org_proj_name
end

# store the default registry scheme type by doing 'oc get dc/docker-registry -o yaml'
Given /^I store the default registry scheme to the#{OPT_SYM} clipboard$/ do |cb_name|
  ensure_admin_tagged
  cb_name ||= :registry_scheme
  @result = admin.cli_exec(:get, resource: 'dc', resource_name: 'docker-registry', n: 'default', o: 'yaml')
  # try ds if we got nothing from dc
  @result = admin.cli_exec(:get, resource: 'ds', resource_name: 'docker-registry', n: 'default', o: 'yaml') unless @result[:success]
  @result[:parsed] = YAML.load(@result[:response])
  cb[cb_name] = @result[:parsed].dig('spec', 'template', 'spec', 'containers')[0].dig('livenessProbe','httpGet','scheme').downcase
end

# Generate registry route for online and dedicated environments
Given /^I attempt the registry route based on API url and store it in the#{OPT_SYM} clipboard$/ do |cb_name|
  api_hostname = env.api_hostname
  raise "The API route got from env is incorrect" unless api_hostname =~ /api\..+/
  cb_name ||= :registry_route
  cb[cb_name] = api_hostname.gsub("api","registry")
end

# Generate default route
Given /^I enable image-registry default route$/ do
  ensure_admin_tagged
  org_proj_name = project(generate: false).name rescue nil

  step 'I run the :patch admin command with:', table(%{
      | resource      | configs.imageregistry.operator.openshift.io                 |
      | resource_name | cluster                                                     |
      | p             | {"spec":{"defaultRoute":true,"managementState": "Managed"}} |
      | type          | merge                                                       |
  })
  step %Q/the step should succeed/
  step %Q/admin waits for the "image-registry" service to become ready in the "openshift-image-registry" project/
  step %Q/admin waits for the "default-route" route to appear in the "openshift-image-registry" project up to 120 seconds/
  project(org_proj_name) if org_proj_name
end

Given /^default image registry route is stored in the#{OPT_SYM} clipboard$/ do |cb_name| 
  ensure_admin_tagged
  org_proj_name = project(generate: false).name rescue nil
  cb_name ||= :registry_route
  cb[cb_name] = route('default-route', service('image-registry',project('openshift-image-registry'))).dns(by: admin)
  project(org_proj_name) if org_proj_name
end

Given /^current generation number of#{OPT_QUOTED} deployment is stored into#{OPT_SYM} clipboard$/ do |name, cb_name|
  cb_name ||= :generation_number
  cb[cb_name] = deployment(name).generation_number(user: user, cached: false)
end

Given /^docker config for default image registry is stored to the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :dockercfg_file
  step %Q/I enable image-registry default route/
  step %Q/default image registry route is stored in the :integrated_reg_ip clipboard/
  step %Q/a 5 characters random string of type :dns is stored into the :dockercfg_name clipboard/
  cb[cb_name] ="/tmp/#{cb.dockercfg_name}"

  cb.generated_cfg={
        "#{cb.integrated_reg_ip}" => {
          "auth" => Base64.strict_encode64(
            "#{user.name}:#{user.cached_tokens.first}"
          ),
        } 
  }

  File.open("#{cb[cb_name]}", 'wb') { |f| 
    f.write(
       {   
         "auths" => cb.generated_cfg
       }.to_json
    )
  }
end

Given /^certification for default image registry is stored to the#{OPT_SYM} clipboard$/ do |cb_name|
  ensure_admin_tagged
  cb_name ||= :reg_crt_name
  
  step %Q/a 5 characters random string of type :dns is stored into the :regcrt clipboard/
  cb[cb_name] ="/tmp/#{cb.regcrt}.crt"

  org_user = @user
  org_proj_name = project.name
  @user = admin
  @result = secret("router-certs-default", project("openshift-ingress", switch: false)).value_of("tls.crt")
  File.open("#{cb[cb_name]}", 'wb') { |f| 
    f.write(@result)
  }

  @user = org_user
  project(org_proj_name)
end
