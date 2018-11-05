Given /^the origin e2e test pod is executed$/ do
  version, major, minor = env.get_version(user: user)

  @result = user.cli_exec(
    :run,
    name: "e2e-runner",
    image: "aosqe/e2e-runner:#{major}:#{minor}"
    # TODO: additional options if needed
  )

  unless @result[:success]
    raise "could not start e2e-runner, see log"
  end

  # TODO: run commands on pod and add additional checks if needed
end
