#!/usr/bin/env ruby

require 'commander'
require 'open-uri'
require 'nokogiri'
require 'thread'

"""
Utility to query release page for matching payload containing a fix/PR matching a description provider by the user
"""

class QueryPayload
  include Commander::Methods
  # include whatever modules you need

  def run
    program :name, 'find_image'
    program :version, '0.0.1'
    program :description, 'Query the release page to find a matching image based on user defined query parameter'

    default_command :query

    command :query do |c|
      c.syntax = 'query_images pattern, [options]'
      c.description = ''
      c.example 'description', 'command example'
      c.option('-q', "--query QUERY_STRING", "search string")
      c.option('-b', "--build_type BUILD_TYPE", "build type to filter out (ci-|nightly-)")
      c.option('-u', "--url RELEASE_PAGE_URL", "URL of the release page")
      c.action do |args, options|
        options.default \
          :build_type => "nightly-",
          :url => "https://amd64.ocp.releases.ci.openshift.org/"
        raise "missing query string" if options.query.nil?
        print("Querying #{options.url} against #{options.build_type}\n")
        doc = Nokogiri::HTML(URI(options.url).open.read)
        links = doc.xpath("//a[contains(text(), '#{options.build_type}')]")

        target_links = links.map { |l|  options.url + l.attributes['href'].value }
        threads = []
        target_links.each do |link|
          threads << Thread.new(link) do |i|
            doc = Nokogiri::HTML(URI(link).open.read)
              if doc.to_s.include? options.query
                puts "Pattern '#{options.query}' found in payload: #{link}"
              end
          end
        end
        threads.each { |thr| thr.join }
      end
    end

    run!
  end
end

if $0 == __FILE__
  QueryPayload.new.run
end
