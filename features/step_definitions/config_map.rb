Given /^value of #{QUOTED} in configmap #{QUOTED} as YAML is merged with:$/ do |key, cm_name, yaml|
  current_content = YAML.load config_map(cm_name).value_of(key)
  to_merge_content = YAML.load yaml

  deep_merge!(current_content, to_merge_content)

  config_map(cm_name).set_value(key, current_content.to_yaml, user: user)
end

Given /^I store the leader node name from the #{QUOTED} configmap to the#{OPT_SYM} clipboard$/ do | cm_name, cb_name |

  cb_name ||= "holderIdentity"
  rr = config_map(cm_name).raw_resource
  leader_str = rr.dig('metadata', 'annotations', 'control-plane.alpha.kubernetes.io/leader')
  leader_yaml = YAML.load(leader_str)
  cb[cb_name] = leader_yaml.dig("holderIdentity")

end
