Given /^value of #{QUOTED} in configmap #{QUOTED} as YAML is merged with:$/ do |key, cm_name, yaml|
  transform binding, :key, :cm_name, :yaml
  current_content = YAML.load config_map(cm_name).value_of(key)
  to_merge_content = YAML.load yaml

  deep_merge!(current_content, to_merge_content)

  config_map(cm_name).set_value(key, current_content.to_yaml, user: user)
end
