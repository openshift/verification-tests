Given /^a secret is created for admin kubeconfig in current project$/ do
  ensure_admin_tagged

  view_opts = { output: "yaml", minify: true, flatten: true, _timeout: 20 }
  @result = admin.cli_exec(:config_view, **view_opts, _quiet: true)

  unless @result[:success]
    raise "cannot read admin configuration by: #{res[:instruction]}"
  end

  Tempfile.create(['admin','.kubeconfig']) do |f|
    f.write(@result[:response])
    f.close
    # secret name `admin-kubeconfig` must match template of e2e tests
    @result = admin.cli_exec(:secret_new,
                             secret_name: "admin-kubeconfig",
                             source: "admin.kubeconfig=#{f.path}",
                             n: project.name)
  end

  unless @result[:success]
    raise "cannot create secret, see log"
  end
end
