# get a zone, which in the same region of the master,
#   but not the same zone as master
Given /^a GCE zone without any cluster masters is stored in the#{OPT_SYM} clipboard$/ do |clipboard|
  transform binding, :clipboard
  clipboard ||= "zone"
  regions = BushSlicer::GCE.regions
  getzonecmd = "curl -sS -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/zone | sed -re 's#.*/(.+)$#\\1#'"
  current_zones = env.master_hosts.map{|h| h.exec_checked(getzonecmd)[:response]}.uniq
  allowed_zones = regions.reject {|r,z| (z&current_zones).empty?}.map(&:last).reduce([], &:+)
  cb[clipboard] = (allowed_zones - current_zones).sample
end
