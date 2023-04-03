Before('@clusterlogging') do
  unless $dts_test_preparation_done
    step %Q/logging operators are installed successfully/
    step %Q/the step should succeed/
    $dts_test_preparation_done = true
  end
end

# @commonlogging means there is no special settings for the case to run
Before('@commonlogging') do
  step %Q/I switch to cluster admin pseudo user/
  step %Q/I use the "openshift-logging" project/
  unless cluster_logging("instance").exists?
    if env.version_cmp('4.5', user: user) < 0
      example_cr = "<%= BushSlicer::HOME %>/testdata/logging/clusterlogging/example.yaml"
    else
      step %Q/the correct directory name of clusterlogging file is stored in the :cl_dir clipboard/
      example_cr = "<%= BushSlicer::HOME %>/testdata/logging/clusterlogging/<%= cb.cl_dir %>/example_indexmanagement.yaml"
    end
    step %Q/I create clusterlogging instance with:/, table(%{
      | remove_logging_pods | false         |
      | crd_yaml            | #{example_cr} |
    })
  end
end
