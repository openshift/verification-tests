Given /^the(?: "([^"]*)")? image stream was created$/ do |is_name|
  transform binding, :is_name
  @result = image_stream(is_name).wait_to_appear(user, 30)

  unless @result[:success]
    raise "ImageStream #{is_name} never created"
  end
end

Given /^the(?: "([^"]*)")? image stream becomes ready$/ do |is_name|
  transform binding, :is_name
  @result = image_stream(is_name).wait_till_ready(user,120)

  unless @result[:success]
    raise "ImageStream #{is_name} did not become ready"
  end
end

Given /^I store the image stream tag of the#{OPT_QUOTED} image stream latest tag in the#{OPT_SYM} clipboard$/ do |is_spec, cb_name|
  transform binding, :is_spec, :cb_name
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
  transform binding, :istag_name
  @result = image_stream_tag(istag_name).wait_to_appear(user, 30)

  unless @result[:success]
    raise "ImageStreamTag #{istag_name} never created"
  end
end
