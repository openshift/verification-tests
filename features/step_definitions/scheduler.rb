Given /^the #{QUOTED} scheduler priorityclasses is restored after scenario$/ do |name|
  _admin = admin
  teardown_add {
    opts = {object_type: 'priorityclasses', object_name_or_id: name}
    @result = _admin.cli_exec(:delete, **opts)
    raise "Cannot delete priorityclass: #{name}" unless @result[:success]
  }
end
