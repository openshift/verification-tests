Given /^the #{QUOTED} scheduler priorityclasses is restored after scenario$/ do |name|
  ensure_admin_tagged
  ensure_destructive_tagged
  @result = admin.cli_exec(:delete, object_type: 'priorityclasses', object_name_or_id: name)
  raise "priority classes were not deleted successfully!" unless @result[:success]
end
