Given /^I obtain test data (file|dir) #{QUOTED}(?: into the #{QUOTED} dir)?$/ do |type, path, dest_dir|
  accepted_roots = [
    "#{BushSlicer::HOME}/testdata",
    "#{BushSlicer::HOME}/features/tierN/testdata",
  ]
  tried_paths = []
  found = accepted_roots.any? do |root|
    src = "#{root}/#{path}"
    tried_paths << src
    if File.exist? src
      dest = File.basename(path)
      if dest_dir
        FileUtils.mkdir_p(dest_dir)
        dest = File.join(dest_dir, dest)
      end
      if type == "dir"
        # copy the contents not the dir by appending '/.'
        # otherwise if the dest dir already exists (e.g. step is run twice)
        # cp_r('src', 'dest') will copy src/x -> dest/src/x when instead we want src/x -> dest/x
        FileUtils.cp_r(File.join(src, "."), dest, verbose: true)
      else
        FileUtils.cp(src, dest, verbose: true)
      end
      cb.test_file = File.absolute_path(dest)
    end
  end
  raise "could not find test file in '#{tried_paths}'" unless found
end

Given /^I save the (output|response) to file>(.+)$/ do |part, filepath|
  part = part == "response"? :response : :stdout
  File.write(File.expand_path(filepath.strip), @result[part])
end

Given /^I get time difference using "(.+)" and "(.+)" in (.+) file$/ do  |s1, s2, filename|
  ##This isn't a generic step-definition yet & specific to logs of machineset-controller##
  split1 = File.open(filename){ |f| f.read }.split(s1)[0].split("Watching")[0]
  split2 = File.open(filename){ |f| f.read }.split(s2)[0].split(s1)[2].strip

  puts "DEBUG split1: #{split1}"
  puts "DEBUG split2: #{split2}"

  #Calculating time difference in seconds
  time_start = DateTime.parse split1
  time_end = DateTime.parse split2
  time_difference = ((time_end - time_start)* 24 * 60 * 60).to_i
  if time_difference > 30
    raise ("Upgrade can cause issues for new machinesets")
  end
end
# This step is used to delete lines from file. If multiline match is needed,
#   then write another step. If pattern starts with '/' or '%r{' treat as RE.
#   Relative paths are considered inside workdir.
Given /^I delete matching lines from "(.+)":$/ do |file, table|

  # deal with relative file names
  if !file.start_with?("/")
    file = File.join(localhost.workdir, file)
  end

  # put all patterns in an array for efficiency
  patterns = []
  table.raw.flatten.each do |pattern|
    if pattern.start_with?('/') && pattern.end_with?('/')
      patterns << Regexp.new(pattern[1..-2])
    elsif pattern.start_with?('%r{') && pattern.end_with?('}')
      patterns << Regexp.new(pattern[3..-2])
    else
      patterns << pattern
    end
  end

  # use copy to keep the same execution permission
  FileUtils.cp(file,"#{file}.test")
  # delete the lines from the file
  File.open("#{file}.test","w") do |filenew|
    File.foreach(file) do |line|
      filenew.puts line unless patterns.find {|p| line.index(p)}
    end
  end

  FileUtils.mv("#{file}.test",file)
end

# This step is used to replace strings and patterns in file. If pattern starts
#   with '/' or '%r{' treat as RE. Relative paths are considered inside workdir.
Given /^I replace (lines|content) in "(.+)":$/ do |mode, file, table|

  # deal with relative file names
  if !file.start_with?("/")
    file = File.join(localhost.workdir, file)
  end

  # put all the patterns and replacements to the array for efficient
  patterns = []
  patterns = table.raw.map do |pattern, replacement|
    if pattern.start_with?('/') && pattern.end_with?('/')
      [Regexp.new(pattern[1..-2]), replacement]
    elsif pattern.start_with?('%r{') && pattern.end_with?('}')
      [Regexp.new(pattern[3..-2]), replacement]
    else
      [pattern, replacement]
    end
  end

  # use copy to keep the same execution permission
  FileUtils.cp(file,"#{file}.test")
  # replace lines
  File.open("#{file}.test","w") do |filenew|
    if mode == "lines"
      success = false
      File.foreach(file) do |line|
        # replace the old string with new string
        # when gsub! (but not gsub) has nothign to replace, it returns 'nil'
        patterns.each do |pattern, repl_string|
          success = success | line.gsub!(pattern, repl_string)
        end
        filenew.puts line
      end
      unless success
        raise "The substitution failed, please check your parameters."
      end
    elsif mode == "content"
      content = File.read(file)
      patterns.each do |pattern, repl_string|
        unless content.gsub!(pattern, repl_string)
          raise "The substitution failed, please check your parameters."
        end
      end
      filenew.write content
    end
  end
  FileUtils.mv("#{file}.test",file)
end

# author gusun@redhat.com
# Note This step is used to restore the modified file
# Usage
#
#    Given I backup the "/home/gusun/test/file" file
#
Given(/^I backup the file "(.+)"$/) do |file|
  file.strip!
  filename = File.basename(file)

  if File.exist?("#{filename}.bak")
    raise "Backup already exists."
  else
    FileUtils.cp(file,"#{filename}.bak")
  end

  teardown_add {
    File.delete("#{filename}.bak") if File.exist?("#{filename}.bak")
  }
end

# author gusun@redhat.com
# Note This step is used to restore the modified file
# Usage
#
#    Given I restore the "/home/gusun/test/file" file
#
Given /^I restore the file "(.+)"$/ do |file|
  file.strip!
  filename = File.basename(file)

  if !File.exist?("#{filename}.bak")
    raise "There is no #{filename}.bak backup."
  else
    FileUtils.rm(file) if File.exist?(file)
    FileUtils.mv("./#{filename}.bak",file)
  end
end

# @param [String] path Path to the file
# @param [Table] table Contents of the file
# @note Creates a local file with the given content
Given /^(?:a|the) "([^"]+)" file is (created|appended) with the following lines:$/ do |path, action, table|
  mode = "w" if action =~ /created/
  mode = "a" if action =~ /appended/
  FileUtils::mkdir_p File.expand_path(File::dirname(path))
  File.open(File.expand_path(path), mode) { |f|
    if table.respond_to? :raw
      table.raw.each do |row|
        f.write("#{row[0]}\n")
      end
    else
      f.write(table)
    end
  }
end

Given /^I create the #{QUOTED} directory$/ do |path|
  FileUtils.mkdir_p(path)
end

# @author cryan@redhat.com
# @param [String] path Path to the file
# @note Deletes a local file
Given /^(?:a|the) "([^"]+)" file is deleted( if it exists)?$/ do |file, graceful|
  if File.exist?(file)
    FileUtils.rm(file)
  else
    if graceful
      logger.warn("The file is not exists")
    else
      raise "Unable to delete the file; please check the path/filename."
    end
  end
end

# @author cryan@redhat.com
# @param [String] path Path to the file
# @note Checks for the presence or absence of a local file
Given /^(?:a|the) "([^"]+)" file is( not)? present$/ do |file, negative|
  if File.exist?(file)
    if negative
      raise "The file exists, when it should not."
    end
  else
    if negative.nil?
      raise "The file is not present."
    end
  end
end

Given /^the #{QUOTED} directory listing is stored in the#{OPT_SYM} clipboard$/ do |dir_name, cb_name|
  cb_name ||= :dir_list
  # ignore the . and .. entries
  cb[cb_name] = Dir.entries(dir_name) - ['.', '..']
end

# @author pruan@redhat.com
# @param [String] directory name we want to list
# @return [Boolean] true if directory contains all of the expected, false otherwise
Given /^the #{QUOTED} directory contains:$/ do |dir_name, table|
  # ignore the . and .. entries
  dir_list = Dir.entries(dir_name) - ['.', '..']
  expected_list = table.raw.flatten
  missing_files = expected_list - dir_list
  raise "Directory #{dir_name} does not contain #{missing_files}" unless missing_files.empty?
end

Given /^the #{QUOTED} directory is removed$/ do | dir_name |
  localhost.delete(File.expand_path(dir_name), r: true)
end

Given /^the #{QUOTED} file is made executable$/ do | filename |
  FileUtils.chmod("a+x",filename)
end

Given /^I read the #{QUOTED} file$/ do |path|
  file = expand_path path # lets fail if file is not found

  @result = {
    exitstatus: -1,
    response: file ? File.read(file) : "",
    instruction: "read #{path} into @result",
    success: !! file
  }
end
