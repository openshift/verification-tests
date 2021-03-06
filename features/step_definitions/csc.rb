# supporting steps for clusterserviceclass
#

# get all listing and cache the result cb[cb_name] will have a copy of the
# indexed listing
Given /^cluster service classes are indexed by external name in the#{OPT_SYM} clipboard$/ do | cb_name |
  transform binding, :cb_name
  cb_name ||= :csc_list
  cb[cb_name] = BushSlicer::ClusterServiceClass.list(user: admin).map { |csc|
    [csc.external_name, csc]
  }.to_h
  cache_resources *cb[cb_name].values
end

