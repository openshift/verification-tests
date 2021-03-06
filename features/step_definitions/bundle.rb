Given /^bundles( in the#{OPT_QUOTED} project)? with qualified name matching #{RE} are stored in the#{OPT_SYM} clipboard$/ do |in_project, pr_name, pattern, cb_name|
  transform binding, :in_project, :pr_name, :pattern, :cb_name
  cb_name ||= "bundles"
  project(pr_name, generate: false)
  re = Regexp.new(pattern)
  clazz = resource_class("bundles")

  list = clazz.list(user: user, project: project)
  logger.info("#{clazz::RESOURCE}: #{list.map(&:name)}")
  cb[cb_name] = list.select { |r| re =~ r.fq_name }
  cache_resources *list
  cache_resources cb[cb_name].first if cb[cb_name].first
end
