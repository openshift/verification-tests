## NAME              DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
##hello-daemonset   1         1         1         1            1           <none>          4m
Given /^#{QUOTED} daemonset becomes ready in the#{OPT_QUOTED} project$/ do | d_name, proj_name |
  transform binding, :d_name, :proj_name
  proj_name ||= project.name
  project(proj_name)
  seconds = 5 * 60
  success = wait_for(seconds) {
    desired = daemon_set(d_name).desired_replicas
    ready = daemon_set(d_name).ready_replicas(cached: false)
    ready == desired
  }
  raise "Daemonset did not become ready" unless success
end

