# store here steps that create test services within OpenShift test env

Given /^I have a NFS service in the(?: "([^ ]+?)")? project$/ do |project_name|
  ensure_admin_tagged

  project(project_name)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  step %Q/SCC "privileged" is added to the "system:serviceaccounts:<%= project.name %>" group/
  step 'I obtain test data file "storage/nfs/nfs-server.yaml"'
  step %Q{I run the :create client command with:}, table(%{
    | f | <%= BushSlicer::HOME %>/testdata/storage/nfs/nfs-server.yaml |
  })
  step %Q/the step should succeed/

  step 'I wait for the "nfs-service" service to become ready up to 300 seconds'
  # now you have NFS running, to get IP, call `service.ip` or
  #   `service("nfs-service").ip`

  @result = pod("nfs-server").exec("bash", "-c", "chmod g+w /mnt/data", as: user)
  step %Q/the step should succeed/
end

#This is a step to create nfs-provisioner pod or dc in the project
Given /^I have a nfs-provisioner (pod|service) in the(?: "([^ ]+?)")? project$/ do |deploymode, project_name|
  ensure_admin_tagged
  _service = deploymode == "service" ? true : false
  _project = project(project_name)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end
  _deployment = deployment("nfs-provisioner", _project)
  _scc = security_context_constraints("nfs-provisioner")
  _deployment.ensure_deleted(user: admin)
  _scc.ensure_deleted(user: admin)
  step %Q{the following scc policy is created: https://raw.githubusercontent.com/openshift/external-storage/master/nfs/deploy/kubernetes/scc.yaml}
  step %Q/SCC "nfs-provisioner" is added to the "system:serviceaccount:<%= project.name %>:nfs-provisioner" service account/
  # To make sure the nfs-provisioner role is deleted which is created mannually by user
  step %Q/admin ensures "nfs-provisioner-runner" clusterrole is deleted/
  step %Q|I download a file from "https://raw.githubusercontent.com/openshift/external-storage/master/nfs/deploy/kubernetes/rbac.yaml"|
  file_name = @result[:file_name]
  step %Q/I replace content in "#{file_name}":/, table(%{
    | default | <%= project.name %> |
    })
  @result = admin.cli_exec(:create, n: project.name, f: file_name)
  raise "could not create nfs-provisioner rbac" unless @result[:success]
  env.nodes.map(&:host).each do |host|
    setup_commands = [
      "mkdir -p /srv/",
      "chcon -Rt svirt_sandbox_file_t /srv/"
    ]
    res = host.exec_admin(*setup_commands)
    raise "Set up hostpath for nfs-provisioner failed" unless @result[:success]
  end
  if _service
    @result = admin.cli_exec(:create, n: project.name, f: "https://raw.githubusercontent.com/openshift/external-storage/master/nfs/deploy/kubernetes/deployment.yaml")
    raise "could not create nfs-provisioner deployment" unless @result[:success]
    step %Q/a pod becomes ready with labels:/, table(%{
      | app=nfs-provisioner |
      })
  else
    @result = admin.cli_exec(:create, n: project.name, f: "https://raw.githubusercontent.com/openshift/external-storage/master/nfs/deploy/kubernetes/pod.yaml")
    raise "could not create nfs-provisioner pod" unless @result[:success]
  end
  unless storage_class("nfs-provisioner-"+project.name).exists?(user: admin, quiet: true)
    step %Q{admin creates a StorageClass from "https://raw.githubusercontent.com/openshift/external-storage/master/nfs/deploy/kubernetes/class.yaml" where:}, table(%{
      | ["metadata"]["name"] | nfs-provisioner-<%= project.name %> |
      })
    step %Q/the step should succeed/
  end
end

#This is a step to create efs-provisioner service in the project
Given /^I have a efs-provisioner(?: with fsid "(.+)")?(?: of region "(.+)")? in the(?: "([^ ]+?)")? project$/ do |fsid, region, project_name|
  ensure_admin_tagged
  _project = project(project_name)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end
  _deployment = deployment("efs-provisioner", _project)
  _deployment.ensure_deleted(user: admin)
  #Create configmap,secret,sa,deployment
  step %Q{I obtain test data file "configmap/efsconfigm.yaml"}
  cm = YAML.load(@result[:response])
  path = @result[:abs_path]
  cm["data"]["file.system.id"] = fsid if fsid
  cm["data"]["aws.region"] = region if region
  fsid ||= cm["data"]["file.system.id"]
  region ||= cm["data"]["aws.region"]
  File.write(path, cm.to_yaml)
  @result = user.cli_exec(:create, f: path)
  raise "Could not create efs-provisioner configmap" unless @result[:success]
  step %Q/SCC "hostmount-anyuid" is added to the "system:serviceaccount:<%= project.name %>:efs-provisioner" service account/
  # To make sure the efs-provisioner role is deleted which is created mannually by user
  step %Q/admin ensures "efs-provisioner-runner" clusterrole is deleted/
  step %Q|I download a file from "https://raw.githubusercontent.com/openshift/external-storage/master/aws/efs/deploy/rbac.yaml"|
  file_name = @result[:file_name]
  step %Q/I replace content in "#{file_name}":/, table(%{
    | default | <%= project.name %> |
    })
  @result = admin.cli_exec(:create, n: project.name, f: file_name)
  raise "could not create efs-provisioner rbac" unless @result[:success]
  step %Q|I download a file from "https://raw.githubusercontent.com/openshift/external-storage/master/aws/efs/deploy/deployment.yaml"|
  file_name = @result[:file_name]
  step %Q/I replace content in "#{file_name}":/, table(%{
    | /image:.*/  | image: openshift3/ose-efs-provisioner       |
    | /server:.*/ | server: #{fsid}.efs.#{region}.amazonaws.com |
    | /path:.*/   | path: /                                     |
    })
  @result = user.cli_exec(:create, f: file_name)
  raise "Could not create efs-provisioner deployment" unless @result[:success]
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=efs-provisioner |
    })
end

#The following helper step will create a squid proxy, and
#save the service ip and port of the proxy pod for later use in the scenario.
Given /^I have a(n authenticated)? proxy configured in the project$/ do |use_auth|
  if use_auth
    step %Q/I run the :create_deploymentconfig client command with:/, table(%{
      | image | quay.io/openshifttest/squid-proxy |
      | name  | squid-proxy                       |
      })
    step %Q/I wait until the status of deployment "squid-proxy" becomes :running/
    step %Q/I run the :set_env client command with:/, table(%{
      | resource | deploymentconfig/squid-proxy |
      | e        | USE_AUTH=1                   |
      })
    step %Q/a pod becomes ready with labels:/, table(%{
      | deployment=squid-proxy-2 |
      })
    @result = user.cli_exec(:expose, resource: "deploymentconfig", resource_name: "squid-proxy", port: "3128")
  else
    step %Q/I run the :create_deployment client command with:/, table(%{
      | image | quay.io/openshifttest/squid-proxy |
      | name  | squid-proxy                       |
      })
    step %Q/a pod becomes ready with labels:/, table(%{
      | app=squid-proxy |
      })
    @result = user.cli_exec(:expose, resource: "deployment", resource_name: "squid-proxy", port: "3128")
  end
  step %Q/the step should succeed/
  unless @result[:success]
    raise "could not create squid-proxy service, see log"
  end
  step %Q/I wait for the "squid-proxy" service to become ready/
  step %Q/evaluation of `service.ip` is stored in the :proxy_ip clipboard/
  step %Q/evaluation of `service.ports[0].dig('port')` is stored in the :proxy_port clipboard/
  step %Q/evaluation of `pod` is stored in the :proxy_pod clipboard/
end

Given /^I have LDAP service in my project$/ do
    ###
    # Since we run the scenario in jenkins agent which is not in sdn, then two choices come to me:
    # 1, Create a route for the ldapserver pod, but blocked by this us https://trello.com/c/9TXvMeS2 is done.
    # 2, Port forward the ldap server pod to the jenkins agent.
    # So take the second one since this one can be implemented currently
    ###
    stats = {}
    step %Q/I run the :run client command with:/, table(%{
      | name  | ldapserver                                       |
      | image | quay.io/openshifttest/ldap:multiarch |
      })
    step %Q/the step should succeed/
    step %Q/a pod becomes ready with labels:/, table(%{
      | run=ldapserver |
      })

    cb.ldap_pod = BushSlicer::Pod.get_labeled(["run", "ldapserver"], user: user, project: project).first
    cb.ldap_pod_name = cb.ldap_pod.name
    cache_pods cb.ldap_pod

    step 'I obtain test data file "authorization/init.ldif"'
    step %Q/the step should succeed/

    # Init the test data in ldap server.
    wait_for(60, interval: 5, stats: stats){
      @result = pod.exec("ldapadd", "-x", "-h", "127.0.0.1", "-p", "389", "-D", "cn=Manager,dc=example,dc=com", "-w", "admin", stdin: File.read(cb.test_file), as: user)
      @result[:success]
    }
    logger.info "after #{stats[:seconds]} seconds and #{stats[:iterations]} " <<
                  "iterations, ldapadd result is: " <<
                  "#{@result[:success] ? "success" : @result[:error].inspect}"
    raise "ldapadd failed" unless @result[:success]

    # Port forword ldapserver to local
    step %Q/evaluation of `rand(32000...65536)` is stored in the :ldap_port clipboard/
    step %Q/I run the :port_forward background client command with:/, table(%{
      | pod       | <%= pod.name %>         |
      | port_spec | <%= cb.ldap_port %>:389 |
      })
    step %Q/the step should succeed/
    @result = BushSlicer::Common::Net.wait_for_tcp(host: "localhost", port: cb.ldap_port, timeout: 60)
    stats = @result[:props][:stats]
    logger.info "after #{stats[:seconds]} seconds and #{stats[:iterations]} " <<
      "iterations, localhost is: " <<
      "#{@result[:success] ? "accessible" : @result[:error].inspect}"
    raise "port forwarding is not yet ready" unless @result[:success]
end

Given /^I have an ssh-git service in the(?: "([^ ]+?)")? project$/ do |project_name|
  project(project_name, switch: true)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = user.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/templates/ssh-git/ssh-git-dc.yaml")
  raise "cannot run the ssh-git-server pod" unless @result[:success]

  @result = user.cli_exec(:set_probe, resource: "dc/git-server", readiness: true, open_tcp: "2022")
  raise "cannot set dc/git-server probe" unless @result[:success]

  @result = user.cli_exec(:expose, resource: "dc", resource_name: "git-server", port: "22", target_port: "2022")
  raise "cannot create git-server service" unless @result[:success]

  # wait to become available
  @result = BushSlicer::Pod.wait_for_labeled("deploymentconfig=git-server",
                                            "name=git-server",
                                            count: 1,
                                            user: user,
                                            project: project,
                                            seconds: 300) do |pod, pod_hash|
    pod_hash.dig("spec", "containers", 0, "readinessProbe", "tcpSocket") &&
      pod.ready?(user: user, cached: true)[:success]
  end
  raise "git-server pod did not become ready" unless @result[:success]

  # Setup SSH key
  cache_pods *@result[:matching]
  ssh_key = BushSlicer::SSH::Helper.gen_rsa_key
  @result = pod.exec(
    "bash", "-c",
    "echo '#{ssh_key.to_pub_key_string}' >> /home/git/.ssh/authorized_keys",
    as: user
  )
  raise "cannot add public key to ssh-git server pod" unless @result[:success]
  # add the private key to git server pod ,so we can make this pod also as a git client pod to pull/push code to the repo
  @result = pod.exec(
    "bash", "-c",
    "echo '#{ssh_key.to_pem}' >> /home/git/.ssh/id_rsa && chmod 600 /home/git/.ssh/id_rsa && ssh-keyscan -H #{service("git-server").ip(user: user)}>> ~/.ssh/known_hosts",
    as: user
  )
  raise "cannot add private key to ssh-git server pod" unless @result[:success]
  #git config, we should have this when we git clone a repo
  @result = pod.exec(
    "bash", "-c",
    "git config --global user.email \"sample@redhat.com\" &&  git config --global user.name \"sample\"",
    as: user
  )
  raise "cannot set git global config" unless @result[:success]

  # to get string private key use cb.ssh_private_key.to_pem in scenario
  cb.ssh_private_key = ssh_key
  # set some clipboards for easy access
  cb.git_svc = "git-server"
  cb.git_pod_ip_port = "#{pod.ip(user: user)}:2022"
  cb.git_pod = pod
  cb.git_svc_ip = "#{service("git-server").ip(user: user)}"
  # put sample repo in clipboard for easy use
  cb.git_repo_pod = "ssh://git@#{pod.ip(user: user)}:2022/repos/sample.git"
  cb.git_repo_ip = "git@#{service("git-server").ip(user: user)}:sample.git"
  cb.git_repo = "git@git-server:sample.git"
end

Given /^I have an http-git service in the(?: "([^ ]+?)")? project$/ do |project_name|
  project(project_name, switch: true)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = user.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/image/gitserver/gitserver-ephemeral.yaml")
  # @result = user.cli_exec(:run, name: "gitserver", image: "quay.io/openshifttest/origin-gitserver@sha256:8062457c330f0da521b340f2dceb13c4852d46ec58e45a9ef276a5ec639a328c", env: 'GIT_HOME=/var/lib/git')
  raise "could not create the http-git-server" unless @result[:success]

  @result = user.cli_exec(:policy_add_role_to_user, role: "edit", serviceaccount: "git")
  raise "error with git service account policy" unless @result[:success]

  @result = service("git").wait_till_ready(user, 300)
  raise "git service did not become ready" unless @result[:success]

  ## we assume to get git pod in the result above, fail otherwise
  cache_pods *@result[:matching]
  unless pod.name.start_with? "git-"
    raise("looks like underlying implementation changed and service ready" +
      "status does not return matching pods anymore; report BushSlicer bug")
  end

  # set some clipboards
  cb.git_pod = pod
  cb.git_route = route("git").dns(by: user)
  cb.git_svc = "git"
  cb.git_svc_ip = "#{service("git").ip(user: user)}"
  cb.git_pod_ip_port = "#{pod.ip(user: user)}:8080"
end

Given /^I have a git client pod in the#{OPT_QUOTED} project$/ do |project_name|
  project(project_name, switch: true)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  #@result = user.cli_exec(:create, f: "https://raw.githubusercontent.com/openshift/origin/master/examples/gitserver/gitserver-ephemeral.yaml")
  @result = user.cli_exec(:run, name: "git-client", image: "quay.io/openshifttest/origin-gitserver@sha256:8062457c330f0da521b340f2dceb13c4852d46ec58e45a9ef276a5ec639a328c", env: 'GIT_HOME=/var/lib/git')
  raise "could not create the git client pod" unless @result[:success]

  @result = BushSlicer::Pod.wait_for_labeled("run=git-client", count: 1,
                                            user: user, project: project, seconds: 300)
  raise "#{pod.name} pod did not become ready" unless @result[:success]

  cache_pods(*@result[:matching])

  @result = pod.wait_till_ready(user, 300)

  unless @result[:success]
    logger.error(@result[:response])
    raise "#{pod.name} pod did not become ready"
  end

  # for ssh-git : only need to add private key on git-client pod
  unless cb.ssh_private_key.nil? then
    @result = pod.exec(
        "bash", "-c",
        "echo '#{cb.ssh_private_key.to_pem}' >> /home/git/.ssh/id_rsa && chmod 600 /home/git/.ssh/id_rsa && ssh-keyscan -H #{cb.git_svc_ip}>> ~/.ssh/known_hosts",
        as: user
    )
    raise "cannot add private key to git client server pod" unless @result[:success]
  end

  # for http-git : only need to config credential
  # due to this bug: https://bugzilla.redhat.com/show_bug.cgi?id=1353407
  # currently we use user token instead of service account
  if cb.ssh_private_key.nil? then
    @result = pod.exec(
        "bash", "-c",
        "git config --global credential.http://#{cb.git_svc_ip}:8080.helper '!f() { echo \"username=#{user.name}\"; echo \"password=#{user.cached_tokens.first}\"; }; f'",
        as: user
    )
    raise "cannot set git client pod global config" unless @result[:success]
  end

  # only set pod name to clipboards
  cb.git_client_pod = pod
end

# pod-for-ping is a pod that has curl, wget, telnet and ncat
Given /^I have a pod-for-ping in the#{OPT_QUOTED} project$/ do |project_name|
  project(project_name, switch: true)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = user.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/networking/aosqe-pod-for-ping.json")
  raise "could not create a pod-for-ping" unless @result[:success]

  cb.ping_pod = pod("hello-pod")
  @result = pod("hello-pod").wait_till_ready(user, 300)
  unless @result[:success]
    pod.describe(user, quiet: false)
    raise "pod-for-ping did not become ready in time"
  end
end

# headertest is a service that returns all HTTP request headers used by client
Given /^I have a header test service in the#{OPT_QUOTED} project$/ do |project_name|
  project(project_name)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = user.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/routing/header-test/dc.json")
  raise "could not create header test dc" unless @result[:success]
  cb.header_test_dc = dc("header-test")

  @result = user.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/routing/header-test/insecure-service.json")
  raise "could not create header test svc" unless @result[:success]
  cb.header_test_svc = service("header-test-insecure")

  @result = user.cli_exec(:expose,
                          name: "header-test-insecure",
                          resource: "service",
                          resource_name: "header-test-insecure"
                         )
  raise "could not expose header test svc" unless @result[:success]
  cb.header_test_route = route("header-test-insecure",
                               service("header-test-insecure"))

  @result = BushSlicer::Pod.wait_for_labeled(
    "deploymentconfig=header-test",
    count: 1, user: user, project: project, seconds: 300)
  raise "timeout waiting for header test pod to start" unless @result[:success]
  cache_pods(*@result[:matching])
  cb.header_test_pod = pod

  step 'I wait for a web server to become available via the route'
  cb.req_headers = @result[:response].scan(/^\s+(.+?): (.+)$/).to_h
end

# skopeo is a pod that has skopeo clients tools
Given /^I have a skopeo pod in the(?: "([^ ]+?)")? project$/ do |project_name|
  project(project_name, switch: true)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = user.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/deployment/skopeo-deployment.json")
  raise "could not create a skopeo" unless @result[:success]

  step %Q/a pod becomes ready with labels:/, table(%{
        | name=skopeo |
    })

  cb.skopeo_pod = pod
  cb.skopeo_dc = dc("skopeo")
end

# Download the ca.pem to pod-for ping
Given /^CA trust is added to the pod-for-ping$/ do
  @result = cb.ping_pod.exec(
    "bash", "-c",
    "wget https://raw.githubusercontent.com/openshift/verification-tests/master/testdata/routing/ca.pem -O /tmp/ca-test.pem -T 10 -t 3",
    as: user
  )
  raise "cannot get ca cert" unless @result[:success]
end

Given /^I have a Gluster service in the(?: "([^ ]+?)")? project$/ do |project_name|
  ensure_admin_tagged

  project(project_name)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = admin.cli_exec(:create, n: project.name, f: 'https://raw.githubusercontent.com/openshift-qe/docker-gluster/master/glusterd.json')
  raise "could not create glusterd pod" unless @result[:success]

  @result = user.cli_exec(:create, n: project.name, f: 'https://raw.githubusercontent.com/openshift-qe/docker-gluster/master/service.json')
  raise "could not create glusterd service" unless @result[:success]

  step 'I wait for the "glusterd" service to become ready'

  # now you have Gluster running, to get IP, call `service.ip` or
  #   `service("glusterd").ip`
end

Given /^I have a Ceph pod in the(?: "([^ ]+?)")? project$/ do |project_name|
  ensure_admin_tagged

  project(project_name)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = admin.cli_exec(:create, n: project.name, f: 'https://raw.githubusercontent.com/openshift-qe/docker-rbd/master/rbd-server.json')
  raise "could not create Ceph pod" unless @result[:success]

  @result = user.cli_exec(:create, n: project.name, f: 'https://raw.githubusercontent.com/openshift-qe/docker-rbd/master/rbd-secret.yaml')
  raise "could not create Ceph secret" unless @result[:success]

  step 'the pod named "rbd-server" becomes ready'

  # now you have Ceph running, to get IP, call `pod.ip` or
  #   `pod("rbd-server").ip(user: user)`
end

# Configure CephFS server in current environment
Given /^I have a CephFS pod in the(?: "([^ ]+?)")? project$/ do |project_name|
  ensure_admin_tagged

  project(project_name)
  unless project.exists?(user: user)
    raise "project #{project_name} does not exist"
  end

  @result = admin.cli_exec(:create, n: project.name, f: 'https://raw.githubusercontent.com/openshift-qe/docker-ceph/master/cephfs-server.json')
  raise "could not create CephFS pod" unless @result[:success]

  @result = user.cli_exec(:create, n: project.name, f: 'https://raw.githubusercontent.com/openshift-qe/docker-ceph/master/cephfs-secret.yaml')
  raise "could not create CephFS secret" unless @result[:success]

  step 'the pod named "cephfs-server" becomes ready'

  # now you have CephFS running, to get IP, call `pod.ip` or
  #   `pod("cephfs-server").ip(user: user)`
end

# configure iSCSI in current environment; if already exists, skip; if pod is
#   not ready, then delete and create it again
Given /^I have a iSCSI setup in the environment$/ do
  ensure_admin_tagged

  _project = project("iscsi-target", switch: false)
  if !_project.exists?(user:admin, quiet: true)
    step %Q{admin creates a project with:}, table(%{
      | project_name  | iscsi-target |
      | node_selector |              |
    })
    step %Q{the step should succeed}
  end

  _pod = cb.iscsi_pod = pod("iscsi-target", _project)
  _service = cb.iscsi_service = service("iscsi-target", _project)

  if _pod.ready?(user: admin, quiet: true)[:success]
    logger.info "found existing iSCSI pod, skipping config"
  elsif _pod.exists?(user: admin, quiet: true)
    logger.warn "broken iSCSI pod, will try to recreate keeping other config"
    @result = admin.cli_exec(:delete, n: _project.name, object_type: "pod", object_name_or_id: _pod.name)
    raise "could not delete broken iSCSI pod" unless @result[:success]
  else
    @result = admin.cli_exec(:create, n: _project.name, f: "#{BushSlicer::HOME}/testdata/storage/iscsi/iscsi-target.json")
    raise "could not create iSCSI pod" unless @result[:success]
  end

  if !_service.exists?(user:admin, quiet: true)
    step %Q{I obtain test data file "storage/iscsi/service.json"}
    @result = admin.cli_exec(:create, n: _project.name, f: "service.json")
    raise "could not create iSCSI service" unless @result[:success]
  end

  # setup to work with service
  @result = _pod.wait_till_ready(admin, 120)
  raise "iSCSI pod did not become ready" unless @result[:success]
  iscsi_ip = cb.iscsi_ip = _service.ip(user: admin)
  @result = _pod.exec("targetcli", "/iscsi/iqn.2016-04.test.com:storage.target00/tpg1/portals", "create", iscsi_ip, as: admin)
  raise "could not create portal to iSCSI service" unless @result[:success] unless @result[:stderr].include?("This NetworkPortal already exists in configFS")
end

# Using after step: I have a iSCSI setup in the environment
Given /^I create a second iSCSI path$/ do
  ensure_admin_tagged

  _project = project("iscsi-target", switch: false)
  _pod = cb.iscsi_pod = pod("iscsi-target", _project)
  step %Q{I download a file from "https://raw.githubusercontent.com/openshift-qe/docker-iscsi/master/service.json"}
  service_content = JSON.load(@result[:response])
  path = @result[:abs_path].rpartition(".")[0] + ".yaml"
  service_content["metadata"]["name"] = "iscsi-target-2"
  File.write(path, service_content.to_yaml)
  @result = admin.cli_exec(:create, f: path, namespace: _project.name)
  raise "could not create iSCSI service" unless @result[:success]
  _service_2 = service("iscsi-target-2", _project)
  cb.iscsi_ip_2 = _service_2.ip(user: admin)
  @result = _pod.exec("targetcli", "/iscsi/iqn.2016-04.test.com:storage.target00/tpg1/portals", "create", cb.iscsi_ip_2, as: admin)
  unless @result[:success] || @result[:stderr].include?("This NetworkPortal already exists in configFS")
    raise "could not create portal to iSCSI service"
  end
  @result = _pod.exec("targetcli", "saveconfig", as: admin)

  teardown_add {
    @result = _pod.exec("targetcli", "/iscsi/iqn.2016-04.test.com:storage.target00/tpg1/portals", "delete", cb.iscsi_ip_2, "3260", as: admin)
    raise "could not delete portal to iSCSI service" unless @result[:success]
    @result = _pod.exec("targetcli", "saveconfig", as: admin)
    _service_2.ensure_deleted(user: admin)
  }
end

Given /^I disable the second iSCSI path$/ do
  ensure_destructive_tagged

  _project = project("iscsi-target", switch: false)
  _service_2 = service('iscsi-target-2', _project)
  _service_2.ensure_deleted(user: admin)
end

Given /^default router is disabled and replaced by a duplicate$/ do
  ensure_destructive_tagged
  orig_project = project(0) rescue nil
  _project = project("default")

  step 'default router image is stored into the :default_router_image clipboard'
  @result = dc("router", _project).ready?(user: admin)
  unless @result[:success]
    raise "default router not ready before scenario, fix it first"
  end
  step 'default router replica count is stored in the :router_num clipboard'
  step 'default router replica count is restored after scenario'
  step 'admin ensures "testroute" dc is deleted after scenario'
  step 'admin ensures "testroute" service is deleted after scenario'
  step 'admin ensures "router-testroute-role" clusterrolebinding is deleted after scenario'
  @result = admin.cli_exec(:scale,
                           resource: "dc",
                           name: "router",
                           replicas: "0",
                           n: "default")
  step 'the step should succeed'
  # cmd fails, see https://bugzilla.redhat.com/show_bug.cgi?id=1381378
  @result = admin.cli_exec(:oadm_router,
                           name: "testroute",
                           replicas: cb.router_num.to_s,
                           n: "default",
                           selector: "router=enabled",
                           images: cb.default_router_image)

  cb.new_router_dc = dc("testroute", _project)
  @result = dc.wait_till_status(:complete, admin, 300)
  unless @result[:success]
    user.cli_exec(:logs,
                  resource_name: "dc/#{resource_name}",
                  n: "default")
    raise "dc 'testroute' never completed"
  end

  project(orig_project.name) if orig_project
end

Given /^I have a registry in my project$/ do
  ensure_admin_tagged
  if BushSlicer::Project::SYSTEM_PROJECTS.include?(project(generate: false).name)
    raise "I refuse create registry in a system project: #{project.name}"
  end
  @result = admin.cli_exec(:new_app, docker_image: "quay.io/openshifttest/registry:2", namespace: project.name)
  step %Q/the step should succeed/
  @result = admin.cli_exec(:set_probe, resource: "deploy/registry", readiness: true, liveness: true, get_url: "http://:5000/v2",namespace: project.name)
  step %Q/the step should succeed/
  step %Q/a pod becomes ready with labels:/, table(%{
       | deployment=registry |
  })
  cb.reg_svc_ip = "#{service("registry").ip(user: user)}"
  cb.reg_svc_port = "#{service("registry").ports(user: user)[0].dig("port")}"
  cb.reg_svc_url = "#{cb.reg_svc_ip}:#{cb.reg_svc_port}"
  cb.reg_svc_name = "registry"
end

Given /^I have a registry with htpasswd authentication enabled in my project$/ do
#  ensure_admin_tagged
  if BushSlicer::Project::SYSTEM_PROJECTS.include?(project(generate: false).name)
    raise "I refuse create registry in a system project: #{project.name}"
  end
  @result = admin.cli_exec(:new_app, as_deployment_config:true, docker_image: "quay.io/openshifttest/registry:2", namespace: project.name)
  step %Q/the step should succeed/
  step %Q/a pod becomes ready with labels:/, table(%{
       | deploymentconfig=registry |
  })
  @result = user.cli_exec(:create_secret, secret_type: "generic", name: "htpasswd-secret", from_file: "#{BushSlicer::HOME}/testdata/registry/htpasswd", namespace: project.name)
  step %Q/I run the :set_volume client command with:/, table(%{
    | resource    | dc/registry     |
    | add         | true            |
    | mount-path  | /auth           |
    | type        | secret          |
    | secret-name | htpasswd-secret |
    | namespace   | #{project.name} |
  })
  step %Q/the step should succeed/
  step %Q/I run the :set_env client command with:/, table(%{
    | resource  | dc/registry                                 |
    | e         | REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd  |
    | e         | REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm |
    | e         | REGISTRY_AUTH=htpasswd                      |
    | namespace | #{project.name}                             |
  })
  step %Q/the step should succeed/
  step %Q/a pod becomes ready with labels:/, table(%{
       | deploymentconfig=registry |
  })
  cb.reg_svc_ip = "#{service("registry").ip(user: user)}"
  cb.reg_svc_port = "#{service("registry").ports(user: user)[0].dig("port")}"
  cb.reg_svc_url = "#{cb.reg_svc_ip}:#{cb.reg_svc_port}"
  cb.reg_svc_name = "registry"
  cb.reg_user = "testuser"
  cb.reg_pass = "testpassword"
  step %Q/I run the :patch client command with:/, table(%{
      | resource      | dc                                                                                                                                                                                                                                 |
      | resource_name | registry                                                                                                                                                                                                                           |
      | p             | {"spec":{"template":{"spec":{"containers":[{"name":"registry","readinessProbe":{"httpGet":{"httpHeaders":[{"name":"Authorization","value":"Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk"}],"path":"/v2/","port":5000,"scheme":"HTTP"}}}]}}}} |
  })
  step %Q/the step should succeed/
  step %Q/a pod becomes ready with labels:/, table(%{
       | deploymentconfig=registry |
  })
end

Given /^I have a logstash service in the project for kubernetes audit$/ do
  cb.logstash = OpenStruct.new
  @result = user.cli_exec(:create, f: "#{BushSlicer::HOME}/testdata/audit/configmap-simple-logstash.yml")
  unless @result[:success]
    raise "could not create logstash config map, see log"
  end
  cb.logstash.cm = config_map("logstash")

  @result = user.cli_exec(:run, name: "logstash", image: "logstash:6.5.0", env: ["LOGSTASH_HOME=/usr/share/logstash"], command: true, cmd: ["bash", "--", "/etc/logstash/logstash-wrapper.sh", "-f", "/etc/logstash/config"])
  unless @result[:success]
    raise "could not create logstash deployment, see log"
  end
  cb.logstash.dc = dc("logstash")

  @result = user.cli_exec(:set_volume, add: true, "configmap-name": "logstash", "mount-path": "/etc/logstash", resource: "dc/logstash")
  unless @result[:success]
    raise "could not create config map volume for logstash deployment, see log"
  end

  @result = user.cli_exec(:set_volume, add: true, "mount-path": "/var/log", resource: "dc/logstash")
  unless @result[:success]
    raise "could not create log volume for logstash deployment, see log"
  end

  # @result = user.cli_exec(:create_service, createservice_type: "clusterip", name: "logstash", tcp: "8888:8888")
  @result = user.cli_exec(:expose, resource: "dc", resource_name: "logstash", port: "8888")
  unless @result[:success]
    raise "could not create logstash service, see log"
  end
  cb.logstash.svc = service("logstash")

  # @result = user.cli_exec(:patch, resource_name: "logstash", resource: "service", p: '{"spec":{"selector":{"deploymentconfig":"logstash"}}}')
  # unless @result[:success]
  #   raise "could not set service selector, see log"
  # end

  @result = user.cli_exec(:expose, resource: "service", resource_name: "logstash", name: "logstash-http-input")
  unless @result[:success]
    raise "could not create logstash route, see log"
  end
  cb.logstash.route = route("logstash-http-input")

  @result = service("logstash").wait_till_ready(user, 300)
  raise "Logstash service did not become ready" unless @result[:success]

  ## we assume to get git pod in the result above, fail otherwise
  cache_pods *@result[:matching]
  cb.logstash.pod = pod
  cb.logstash.url_http = "http://#{service.hostname}:8888"
  cb.logstash.url_ext = "http://#{route.dns}"
end

Given /^I have a cluster-capacity pod in my project$/ do
  ensure_admin_tagged
  # admin kubeconfig for cluster-capacity
  step 'a secret is created for admin kubeconfig in current project'
  # tested pod yaml files
  step %Q/I run the :create client command with:/, table(%{
    | f         | #{BushSlicer::HOME}/testdata/infrastructure/cluster-capacity/cluster-capacity-configmap.yaml  |
    | namespace | #{project.name} |
  })
  step 'the step should succeed'
  # cluster-capacity as a target pod
  step 'I run oc create over ERB test file: infrastructure/cluster-capacity/cluster-capacity-pod.yaml'
  step 'the step should succeed'
  step 'the pod named "cluster-capacity" becomes ready'
end

Given /^I save a htpasswd registry auth to the#{OPT_SYM} clipboard$/ do |cb_name|
  cb_name ||= :dockercfg_file
  ensure_admin_tagged
  step 'docker config for default image registry is stored to the :default_dockercfg clipboard'
  step 'I have a registry with htpasswd authentication enabled in my project'
  step %Q/I run the :create_route_edge client command with:/, table(%{
    | name    | registry |
    | service | registry |
  })
  step 'the step should succeed'
  step 'I save the hostname of route "registry" in project "<%= project.name %>" to the :custom_registry clipboard'
  step %Q/a 5 characters random string of type :dns is stored into the :dockercfg_name clipboard/
  cb[cb_name] ="/tmp/#{cb.dockercfg_name}"

  cb.new_cfg={
        "#{cb.custom_registry}" => {
          "auth" => Base64.strict_encode64(
            "#{cb.reg_user}:#{cb.reg_pass}"
          ),
        }
  }
  File.open("#{cb[cb_name]}", 'wb') { |f|
    f.write(
       {
         "auths" => cb.generated_cfg.merge(cb.new_cfg)
       }.to_json
    )
  }
end
