Given /^admin ensures the changed secret "([^"]*)" is restored in "([^"]*)" project after scenario$/ do | secret , project |
  ensure_admin_tagged
  teardown_add{
  step %Q{I run the :replace admin command with:}, table(%{
      | _tool | oc                      |
      | f     | #{secret}_original.yaml |
      | n     | #{project}              |
      | force |                         |
  })
  step %Q/the step should succeed/
}
end

