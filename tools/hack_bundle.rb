#!/usr/bin/env ruby

# This file was created to be called instead of `bundle install` mainly to
# avoid recompiling nokogiri gem with questionable usefulness today. Doing
# normal `bundle install` or `gem install -g` should be perfectly fine
# as long as it works and depending on the way verification tests is called.

# Namely, if you call `ruby` or any executable as:
# * bundle exec command
# ** you need to make sure `bundle check` succeeds
# * command # possibly setting RUBYGEMS_GEMDEPS=- environment variable
# ** must have `gem install -g` succeeded
# ** or bundle should have installed gems inside any of Gem.paths, usually [0]
# ** for bundle 2.x the only ways seem to be
# *** run Bundler as root so that gems are installed globally
# *** setting `path` and symlinking Bundler.bundle_path + Bundler.ruby_scope

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
