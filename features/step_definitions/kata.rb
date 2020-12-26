Given /^kata container has been installed successfully(?: in the #{QUOTED} project)?$/ do |ns|
  kata_ns ||= "kata-operator"
  step %Q/I switch to cluster admin pseudo user/
  unless namespace(kata_ns).exists?
    @result = user.cli_exec(:create_namespace, name: kata_ns)
    raise "Failed to create namespace #{kata_ns}" unless @result[:success]
  end
  step %Q/I store master major version in the :master_version clipboard/
  project(kata_ns)
  iaas_type = env.iaas[:type] rescue nil
  accepted_platforms = ['gcp', 'azure']
  raise "Kata installation only supports GCE platform currently." unless accepted_platforms.include? iaas_type
  # check to see if kata already exists
  unless kata_config('example-kataconfig').exists?
    # setup service account
    role_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/role.yaml"
    role_binding_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/role_binding.yaml"
    sa_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/service_account.yaml"
    kataconfigs_crd_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/crds/kataconfiguration.openshift.io_kataconfigs_crd.yaml"
    kata_operator_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/operator.yaml"
    @result = user.cli_exec(:apply, f: role_yaml)
    @result = user.cli_exec(:apply, f: role_binding_yaml)
    @result = user.cli_exec(:apply, f: sa_yaml)
    step %Q/SCC "privileged" is added to the "#{ns}" service account without teardown/
    # step %Q/ give project privileged role to the kata-operator service account/
    # create a custom resource to install the Kata Runtime on all workers
    @result = user.cli_exec(:apply, f: kataconfigs_crd_yaml)
    #raise "Error when creating kataconfig_crd." unless $result[:success]
    @result = user.cli_exec(:create, f: kata_operator_yaml)
    #raise "Error when creating kata operator." unless $esult[:success]
    step %Q/a pod becomes ready with labels:/, table(%{
      | name=kata-operator |
    })
    # install the Kata Runtime on all workers
    kataconfig_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-#{cb.master_version}/deploy/crds/kataconfiguration.openshift.io_v1alpha1_kataconfig_cr.yaml"
    @result = user.cli_exec(:apply, f: kataconfig_yaml)
    raise "Failed to apply kataconfig" unless @result[:success]
    step %Q/I store all worker nodes to the :nodes clipboard/
    step %Q/I wait until number of completed kata runtime nodes match "<%= cb.nodes.count %>" for "example-kataconfig"/
  end
end


Given /^I wait until number of completed kata runtime nodes match #{QUOTED} for #{QUOTED}$/ do |number, kc_name|
  ready_timeout = 900
  matched = kata_config(kc_name).wait_till_installed_counter_match(
    user: user, seconds: ready_timeout, count: number.to_i)
  unless matched[:success]
    raise "Kata runtime did not install into all worker nodes!"
  end
end

Given /^I remove kata operator from #{QUOTED} namespace$/ do | kata_ns |
  # 1. remove kataconfig first
  project(kata_ns)
  kataconfig_name = BushSlicer::KataConfig.list(user: admin).first.name
  step %Q/I ensure "#{kataconfig_name}" kata_config is deleted/
  # 2. remove namespace
  step %Q/I ensure "#{kata_ns}" project is deleted/
end
# # assumption that
And /^I verify kata container runtime is installed into the a worker node$/ do
  # create a project and install sample app has
  org_user = user
  step %Q/I switch to the first user/
  step %Q/I create a new project/
  cb.test_project_name = project.name
  file_path = "kata/release-#{cb.master_version}/example-fedora.yaml"
  step %Q(I run oc create over ERB test file: #{file_path})
  raise "Example kata pod creation failed" unless @result[:success]

  # 1. check pod's spec to make sure the runtimeClassName is 'kata'
  pod_runtime_class_name = pod('example-fedora').raw_resource['spec']['runtimeClassName']
  if pod_runtime_class_name != 'kata'
    raise "Pod's runtimeclass name #{pod_runtime_class_name} should be `kata`"
  end
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=example-kata-fedora-app |
  })
  # 2. check there's a process with the pod name `qemu`
  step %Q/I switch to cluster admin pseudo user/
  node_cmd = "ps aux | grep qemu"
  @result = node(pod.node_name).host.exec_admin(node_cmd)
  raise "No qemu process detected inside pod node" unless @result[:response].include? 'qemu'
end

# generate a cert for the kata-webhook pod which involves
# 1. generate a cert for the webhook
# 2. create certs secrets for k8s
# 3. set the CABundle on the webhook registration yaml
Given /^I install kata-webhook for the#{OPT_QUOTED} namespace$/ do | ns |
  # ignore the admin check if it's for kata
  unless ENV.has_key? 'USE_KATA_RUNTIME' and ENV['USE_KATA_RUNTIME']
    ensure_admin_tagged
  end

  org_user = user
  @user = admin
  ns ||= project.name
  project(ns)
  step %Q{I use the "#{ns}" project}
  key = OpenSSL::PKey::RSA.new(2048)
  public_key = key.public_key
  logger.info("Generating cert for project '#{project.name}")

  webhook_ns = ns
  webhook_name = "pod-annotate"
  webhook_svc = "#{webhook_name}-webhook"
  subject = OpenSSL::X509::Name.parse "CN=#{webhook_svc}.#{webhook_ns}.svc"

  ### generate CSR
  # The CA signs keys through a Certificate Signing Request (CSR). The CSR contains the information necessary to identify the key.
  # openssl req -new -key ./webhookCA.key -subj "/CN=${WEBHOOK_SVC}.${WEBHOOK_NS}.svc" -out ./webhookCA.csr
  csr = OpenSSL::X509::Request.new
  csr.version = 0
  csr.subject = subject
  csr.public_key = public_key
  csr.sign key, OpenSSL::Digest::SHA1.new

  cert = OpenSSL::X509::Certificate.new
  cert.subject = cert.issuer = subject #cert.issuer = OpenSSL::X509::Name.parse(subject)
  cert.not_before = Time.now
  cert.not_after = Time.now + 365 * 24 * 60 * 60
  cert.public_key = public_key
  cert.serial = 0x0
  cert.version = 2

  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = cert
  ef.issuer_certificate = cert
  cert.extensions = [
    ef.create_extension("basicConstraints","CA:TRUE", true),
    ef.create_extension("subjectKeyIdentifier", "hash"),
    # ef.create_extension("keyUsage", "cRLSign,keyCertSign", true),
  ]
  cert.add_extension ef.create_extension("authorityKeyIdentifier",
                                         "keyid:always,issuer:always")

  cert.sign key, OpenSSL::Digest::SHA1.new

  #  save them in the clipboard so testdata/xxx.yaml can use them
  cb.webhook_key_pem = Base64.strict_encode64(key.to_s)
  cb.webhook_cert_pem = Base64.strict_encode64(cert.to_pem)
  cb.ca_bundle = cb.webhook_cert_pem
  logger.info("Creating secret for webhook...")
  step %Q(I run oc apply over ERB test file: kata/webhook/webhook-certs.yaml)
  step %Q(the step should succeed)
  logger.info("Applying webhook registration...")
  step %Q(I run oc apply over ERB test file: kata/webhook/webhook-registration.yaml)
  step %Q(the step should succeed)
  logger.info("Applying webhook.yaml...")
  step %Q(I run oc apply over ERB test file: kata/webhook/webhook.yaml)
  step %Q(the step should succeed)
  ### wait for pod to become ready to make sure
  step %Q/a pod becomes ready with labels:/, table(%{
    | app=pod-annotate-webhook |
  })
  @user = org_user

end
