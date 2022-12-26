source 'https://rubygems.org'
# source 'https://gems.ruby-china.com/'
gem 'json'
# temp workaround for OCPQE-4052 in which Psych 4.x is not compatible with
# cucumber 5.x
gem 'psych', '~> 3.3', '>= 3.3.1'
# gem 'rest-client', '2.0.0.rc2'
gem 'rest-client', '>=2.0'
# gem 'httpclient', '>=2.4'
gem 'net-ssh'
# for ED25519 ssh keys gems `ed25519` and `bcrypt_pbkdf` are also needed
# for RSA keys in the new OPENSSH format (not RSA) then newer net-ssh is needed:
# https://github.com/net-ssh/net-ssh/pull/646
gem 'net-scp'
# gem 'net-ssh-multi'

##### Things to verify on Cucumber upgrade: #####
# the hack in step_definitions/transform.rb
# ReportPortal formatter (in case Formatter API changed
# The PolarShift scenario filter - TestCaseManagerFilter
# BushSlicer::CucuFormatter is we are still uploading html logs to a file server
gem 'cucumber', '~>5.3.0'
#########################

# gem 'rspec', '~>2.14.1'
# gem 'rspec-expectations', '~>2.14.0'
gem 'aws-sdk', '~> 3'
gem 'google-api-client', '~>0.9.2'
gem 'rbvmomi'

gem 'azure-storage', '~> 0.15.0.preview'
gem 'azure_mgmt_storage', '~>0.17.0'
gem 'azure_mgmt_compute', '~>0.18.0'
gem 'azure_mgmt_resources', '~>0.17.0'
gem 'azure_mgmt_network', '~>0.17.0'

# gem 'timers'
## Logging
gem 'term-ansicolor'
## Webauto
gem 'watir'
gem 'headless'
gem 'selenium-webdriver', '~>4.6.0'
gem 'protobuf'
gem 'reportportal'
## Docs
# beware https://github.com/pry/pry/issues/1465
#        https://bugzilla.redhat.com/show_bug.cgi?id=1257578
# gem 'yard-cucumber' # something broken vs pry; requires cucumber 1.3
## Debugging
gem 'pry'
# https://github.com/deivid-rodriguez/pry-byebug/issues/71
#gem 'pry-byebug', :require => false
gem 'byebug'
gem 'jira-ruby'
### XXX 0.1.7 is breaking things need to investigate further, patch this for now
#gem 'configparser', '0.1.6'
gem 'parseconfig'
gem 'nokogiri' # needed here to make tools/hack_bundle.rb work correctly
# oga is a replacemen for nokogiri without system deps; we wrongly thought
#  that we can live without nokogiry but couldn't because of other gem deps
gem 'oga' # replacemen for nokogiri when we thought we can workaround it
# gem 'gherkin', '>=4.0.0'
# gem 'lolsoap'
# gem 'mongo'
# gem 'bson_ext'
# gem 'parseconfig'
# gem 'rake'
# gem 'rails', '~>3.2.0'
# gem 'rhc'
# gem 'mongoid'
# gem 'text-table'
# gem 'terminal-table'
gem 'parallel_tests', '~>3.8.1'
gem 'slack-ruby-client'
