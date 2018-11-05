#!/usr/bin/env ruby

# This file is to be executed instead of `bundle install` to help avoid
# some troubles setting up jenkins slaves. i.e. avoid recompiling some
# existing locally gems. Doing normal `bundle install` should also be
# absolutely fine as long as it works for user.

# Idea is to go about all hack_gemfiles and try to lock currently installed
# local version of gem (if any). We need to copy lockfile so that all gems
# are locked in the same lockfile. Finally copy lock to main dir so that
# we can complete all Gemfiles resolved from elsewhere.
# This trickery is done to avoid recompiling problematic gems like nokogiri
# when we have a local version installed.

main_gemfile_dir = File.dirname __FILE__
main_gemfile = File.join(main_gemfile_dir, "Gemfile")
main_gemfile_lock = main_gemfile + ".lock"
local_gemfiles = File.join(main_gemfile_dir, "hack_gemfiles")

gemdir = Dir.new(local_gemfiles)
gemfiles = []
gemdir.each { |f| gemfiles << f if f =~ /Gemfile_.+/ }

gemfile_lock_last = File.join(local_gemfiles, "Gemfile_init.lock")
File.write(gemfile_lock_last, '')
gemfiles.each do |gemfile|
  gemfile_new = File.join(local_gemfiles, gemfile)
  gemfile_lock_new = gemfile_new + ".lock"
  File.write(gemfile_lock_new, File.read(gemfile_lock_last))
  File.delete(gemfile_lock_last)

  command = "bundle install --gemfile=#{gemfile_new}"
  puts '$ ' + command
  system(command) # ignore errors

  gemfile_lock_last = gemfile_lock_new
end

File.write(main_gemfile_lock, File.read(gemfile_lock_last))
File.delete(gemfile_lock_last)

command = "bundle install --gemfile=#{main_gemfile}"
puts '$ ' + command
ret = system(command)
exit ret.nil? ? 2 : ret
