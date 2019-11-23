#!/usr/bin/env bash

## Source this file to setup proxy according to HOSTS spec

proxy=`ruby -e '
#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path "'$BASH_SOURCE'/../../lib")

# STDERR.puts $LOAD_PATH

require "common"
manager = BushSlicer::Manager.instance
puts manager.environments[manager.conf[:default_environment]].client_proxy
'`

echo Proxy server: "$proxy"

if [[ "$proxy" ]]; then
  export http_proxy="$proxy"
  export https_proxy="$proxy"
fi
