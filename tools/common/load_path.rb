lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..','lib'))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end

