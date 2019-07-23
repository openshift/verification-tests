Given /^the(?: "([^"]*)")? image stream was created$/ do |is_name|
  @result = image_stream(is_name).wait_to_appear(user, 30)

  unless @result[:success]
    raise "ImageStream #{is_name} never created"
  end
end

Given /^the(?: "([^"]*)")? image stream becomes ready$/ do |is_name|
  @result = image_stream(is_name).wait_till_ready(user,120)

  unless @result[:success]
    raise "ImageStream #{is_name} did not become ready"
  end
end

Given /^I store the image stream tag of the#{OPT_QUOTED} image stream latest tag in the#{OPT_SYM} clipboard$/ do |is_spec, cb_name|
  cb_name ||= :tag
  org_project = project(generate: false) rescue nil

  if is_spec
    project_name, is_name = is_spec.split("/", 2)
    unless is_name
      is_name = project_name
      project_name = nil
    end
    is = image_stream(is_name, project(project_name))
  else
    is = image_stream
  end

  cb[cb_name] = image_stream.latest_tag_status.tag.from

  unless BushSlicer::ImageStreamTag === cb[cb_name]
    raise "step expected to see ImageStreamTag as latest tag in the " \
      "#{image_stream.name} image stream but it was #{cb[cb_name].inspect}"
  end

  project(org_project.name) if org_project
end

Given /^the(?: "([^"]*)")? image stream tag was created$/ do |istag_name|
  @result = image_stream_tag(istag_name).wait_to_appear(user, 30)

  unless @result[:success]
    raise "ImageStreamTag #{istag_name} never created"
  end
end

Given /^the #{QUOTED} #{QUOTED} CRD was finalized$/ do |crd_type, crd_name|
  ensure_admin_tagged
  ensure_destructive_tagged
  _user = admin

  @result = admin.cli_exec(:get, resource: crd_type, resource_name: crd_name, o: 'yaml')
  ts1 = @result[:parsed]['metadata']['creationTimestamp']
  
  success = wait_for(300) { 
    @result = admin.cli_exec(:delete, object_type: crd_type, object_name_or_id: crd_name)
  }
  unless success
    raise "The crd #{crd_type} can't be deleted."
  end

  @result = custom_resource_definition(crd_type).wait_to_appear(_user, 60)
  @result = admin.cli_exec(:get, resource: crd_type, resource_name: crd_name, o: 'yaml')
  ts2 = @result[:parsed]['metadata']['creationTimestamp']
  
  unless compare_time(ts1, ts2)
    raise "The crd #{crd_type} doesn't be recreated. "
  end
end
