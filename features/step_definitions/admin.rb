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

Given /^I save the project name hosting #{QUOTED} resource named #{QUOTED} to#{OPT_QUOTED} clipboard/ do |resource, res_name, cb_name|
  ensure_admin_tagged

  cb_name ||= :namespace
  @result = admin.cli_exec(:get, all_namespaces: true, resource: resource, o: 'yaml')
  if @result[:parsed].nil?
    cb[cb_name] = nil
  else
    res = @result[:parsed]['items'].select { |i| i['metadata']['name']==res_name }
    if res.count.zero?
      logger.info("Can't find resource matching name '#{res_name} in any projects")
      cb[cb_name] = nil
    else
      cb[cb_name] = res.first['metadata']['namespace']
    end
  end
end

