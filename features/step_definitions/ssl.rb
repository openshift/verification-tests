# ssl related steps

Given /^the #{QUOTED} cert file is parsed into the#{OPT_SYM} clipboard$/ do |cert_path, cb_name |
  transform binding, :cert_path, :cb_name
  cb_name ||= :cert
  cert = OpenSSL::X509::Certificate.new(File.read(File.expand_path(cert_path)))
  cb[cb_name] = cert
end

Given /^the custom certs are generated with:$/ do |table|
  transform binding, :table
  ensure_admin_tagged
  signer_path = "/etc/origin/master"
  _host = env.master_hosts.first
  cb.subdomain = env.router_default_subdomain(user: user, project: project)
  opts = opts_array_to_hash(table.raw)
  opts[:key] ||= "custom.key"
  opts[:cert] ||= "custom.crt"
  raise "Missing 'hostnames' parameter!" unless opts[:hostnames]
  opts[:signer_cert] ||= signer_path + "/ca.crt"
  opts[:signer_key] ||= signer_path + "/ca.key"
  opts[:signer_serial] ||= signer_path + "/ca.serial.txt"

  # remove the old tls certificates files if exists
  @result = _host.exec_admin("rm -f #{opts[:key]} #{opts[:crt]}")
  step %Q/the step should succeed/
  _oadm_command = "oc adm"
  if env.version_lt("3.3", user: user)
    _oadm_command = "oadm"
  end
  create_custom_cert_cmd = _oadm_command + " ca create-server-cert --signer-cert=#{opts[:signer_cert]} --signer-key=#{opts[:signer_key]} --signer-serial=#{opts[:signer_serial]} --hostnames=#{opts[:hostnames]} --cert=#{opts[:cert]} --key=#{opts[:key]}"
  @result = _host.exec_admin(create_custom_cert_cmd)
  step %Q/the step should succeed/

end

