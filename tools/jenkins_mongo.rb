#!/usr/bin/env ruby

lib_path = File.expand_path(File.dirname(__FILE__))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end
require 'mongo'
require 'common'

# Turn off debug-mode
Mongo::Logger.logger.level = Logger::WARN

module BushSlicer
  # this class is used to query the cached_jenkins database which is used to
  # store the Flexy-install information.  We use this database cache to avoide
  # querying the main jenkins server and also, there's a limitation on how
  # many records are returned with jenkins's query API (100)
  class InstallerLogMongo
    include Common::Helper
    attr_accessor :client, :collections, :query_results

    def initialize
      connect_opts = conf.dig('services', :mongodb, :host_connect_opts)
      #connect_opts = conf['services'][:mongodb][:host_connect_opts]
      host = connect_opts[:hostname]
      port = connect_opts[:port]
      client_host = ["#{host}:#{port}"]
      client_options = {
        database: connect_opts[:db_name],
        user: connect_opts[:username],
        password: connect_opts[:password]
      }
      @client = Mongo::Client.new(client_host, client_options)
      @collections = @client[connect_opts[:db_name]]
    end

    def insert_data(data)
      self.collections.update_one(data, {'$set'=> data}, {:upsert => true})
    end

    # find a document with job_name & job_id match and remove it
    def remove_document(data)
      self.collections.find(data).delete_many
    end

    def get_all_builds(query: nil)
      query ||= {}
      @query_results = self.collections.find(query).to_a
    end

    def get_all_cluster_names
      query = {}
      builds = self.get_all_builds(query: query)
      cnames = builds.map do |b|
        if b['metadata_json']
          YAML.load(b['metadata_json'])['clusterName']
        end
      end
    end

    def construct_build_map
      # query = {"result"=> "SUCCESS"}
      query = {}
      build_map = {}
      build_owner_map = {}
      builds = self.get_all_builds(query: query)
      builds.map do |b|
        infra_id = YAML.load(b['metadata_json'])['infraID'] if b['metadata_json']
        #cluster_name = YAML.load(b['metadata_json'])['clusterName'] if b['metadata_json']
        build_map[infra_id] = b['job_id']
        #build_map[b["instance_prefix"]] = b['job_id']
        if b.has_key? 'user'
          # users installed by Flexy-install has the format  <username-job-id>
          # we just want the username.
          build_owner_map[b['job_id']] = b['user'].split('-').first
        end
      end
      # build_map.keys.compact!
      sorted_keys = build_map.keys.compact.sort
      return build_map, sorted_keys, build_owner_map
    end

  end

end

if __FILE__ == $0
  m = BushSlicer::InstallerLogMongo.new
  m.get_all_cluster_names
end
