Before('@clusterlogging') do
  unless $dts_test_preparation_done
    step %Q/logging operators are installed successfully/
    $dts_test_preparation_done = true
  end
end
