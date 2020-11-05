require 'pry-byebug'
Given /^kata container has been installed successfully(?: in the #{QUOTED} project)?$/ do |ns|
  binding.pry
  kata_ns ||= "kata-operator"
  step %Q/I switch to cluster admin pseudo user/
  unless namespace(kata_ns).exists?
    @result = user.cli_exec(:create_namespace, name: kata_ns)
    raise "Failed to create namespace #{kata_ns}" unless @result[:success]
  end
  project(kata_ns)
  # setup service account
  role_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-4.6/deploy/role.yaml"
  role_binding_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-4.6/deploy/role_binding.yaml"
  sa_yaml = "https://raw.githubusercontent.com/openshift/kata-operator/release-4.6/deploy/service_account.yaml"

end
