#Use this step definition file to create image-specific steps

Given /^I have an?( ephemeral| persistent)? jenkins v#{NUMBER} application(?: from #{QUOTED})?$/ do |type, version, cust_templ|
  transform binding, :type, :version, :cust_templ

  if cust_templ && type
    raise "custom template file and template type should not be " \
      "simultaneously specified"
  elsif cust_templ
    source = "| file | #{cust_templ} |"
  else
    unless type
      scs = BushSlicer::StorageClass.get_matching(user: user) { |sc, sc_hash|
        sc.default?
      }
      if scs.size != 1
        type = "ephemeral"
      else
        t = template("jenkins-persistent", project("openshift", switch: false))
        type = template.exists?(user: user) ? "persistent" : "ephemeral"
      end

      type = scs.size == 1 ? "persistent" : "ephemeral"
    end
    source = "| template | jenkins-#{type.strip} |"
  end

  last_startup_check = monotonic_seconds

  # If we can login to OpenShift via password, then
  #   we can use SSO login.
  # If we only know user token, then we must use
  #   non-SSO login.
  # Installation step also installs based on this.
  if !user.password?
    step %Q/I run the :new_app client command with:/, table(%{
      #{source}
      | p | ENABLE_OAUTH=false                          |
      | p | JENKINS_IMAGE_STREAM_TAG=jenkins:#{version} |
      })
    step 'the step should succeed'
  else
    step %Q/I run the :new_app client command with:/, table(%{
      #{source}
      | p | JENKINS_IMAGE_STREAM_TAG=jenkins:#{version} |
      })
    step 'the step should succeed'
  end
  step 'I wait for the "jenkins" service to become ready up to 600 seconds'
  cb.jenkins_svc = service
  cache_resources *service.pods, route("jenkins", service("jenkins"))
  cb.jenkins_pod = pod
  cb.jenkins_route = route
  cb.jenkins_dns = cb.jenkins_route.dns
  cb.jenkins_major_version = version

    # wait for actual startup as in 3.10+ it is slow on only 512M pod
    # seems like recent jenkins has a delay caused by admin monitor
    # here trying to wait for it's operation to finish
    # possible remedy is DISABLE_ADMINISTRATIVE_MONITOR or give mor RAM to pod
  timeout = 600
  wait_string = "Finished Download metadata."

  started = wait_for(timeout) {
    since = monotonic_seconds - last_startup_check
    res = user.cli_exec(
      :logs,
      resource_name: cb.jenkins_pod.name,
      since: "#{since.to_i + 5}s",
      _quiet: true
    )
    last_startup_check += since
    res[:response].include? wait_string
  }
  if started
    logger.info "Jenkins log line found: #{wait_string}"
  else
    raise "Jenkins failed to start within #{timeout} seconds"
  end
end

Given /^I have a jenkins browser$/ do
  opts = [
    ["rules", "lib/rules/web/images/jenkins_#{cb.jenkins_major_version}/"],
    ["base_url", "https://#{cb.jenkins_dns}"]
  ]
  step 'I have a browser with:', table(opts)
end

# If we can login to OpenShift via password, then
#   we can use SSO login.
# If we only know user token, then we must use
#   non-SSO login.
Given /^I log in to jenkins$/ do
  if env.version_gt("3.11", user: user) && user.password?
    step %Q/I perform the :jenkins_multi_oauth_login web action with:/, table(%{
      | username | <%= user.name %>        |
      | password | <%= user.password %>    |
      | idp      | flexy-htpasswd-provider |
      })
  elsif !user.password?
    step %Q/I perform the :jenkins_standard_login web action with:/, table(%{
      | username | admin    |
      | password | password |
      })
  else
    raise "Please switch to v3 branch to launch automation."
  end
  step 'the step should succeed'
end

Given /^I update #{QUOTED} slave image for jenkins #{NUMBER} server$/ do |slave_name,jenkins_version|
  transform binding, :slave_name, :jenkins_version

  if env.version_gt("3.11", user: user)
    print "Skipped, agent images don't need update above openshift 4.0"
  else
    raise "Please switch to v3 branch to launch automation."
  end

  step 'the step should succeed'
end
