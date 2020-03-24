Before('@clusterlogging') do
  unless $dts_test_preparation_done
    step %Q/logging operators are installed successfully/
    $dts_test_preparation_done = true
  end
end

# @commonlogging means there is no special settings for the case to run
Before('@commonlogging') do
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-logging" project/
  unless cluster_logging("instance").exists?
    step %Q/I create clusterlogging instance with:/, table(%{
      | remove_logging_pods | false                                                                                                  |
      | crd_yaml            | <%= ENV['BUSHSLICER_HOME'] %>/testdata/logging/clusterlogging/example.yaml |
      | log_collector       | fluentd                                                                                                |
    })
  end
end
