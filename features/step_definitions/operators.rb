# operators related helper steps
Given /^all clusteroperators reached version #{QUOTED} successfully$/ do |version|
  ensure_admin_tagged
  clusteroperators = BushSlicer::ClusterOperator.list(user: admin)
  clusteroperators.each do | co |
    raise "version does not match #{version}" unless co.version_exists?(version: version)
    # AVAILABLE   PROGRESSING   DEGRADED
    # True        False         False
    conditions = co.conditions
    expected = {"Degraded"=>"False", "Progressing"=>"False", "Available"=>"True"}
    conditions.each do |k, v|
      # only care about the `expected`, don't compare otherwise
      if expected.keys.include? k
        raise "Failed for condition #{k}" unless expected[k] == v['status']
      end
    end
  end
end


