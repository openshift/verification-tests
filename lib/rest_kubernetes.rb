require 'rest_helper'

module BushSlicer
  module Rest
    module Kubernetes
      extend Helper

      def self.populate(path, base_opts, opts)
        populate_common("/api/<api_version>", path, base_opts, opts)
      end

      class << self
        alias perform perform_common
      end

      # {
      #  "major": "1",
      #  "minor": "3",
      #  "gitVersion": "v1.3.0+507d3a7",
      #  "gitCommit": "447cecf",
      #  "gitTreeState": "clean",
      #  "buildDate": "2016-08-29T14:44:33Z",
      #  "goVersion": "go1.6.2",
      #  "compiler": "gc",
      #  "platform": "linux/amd64"
      # }
      def self.version_k8s(base_opts, opts)
        populate_common("/version", "", base_opts, opts)
        return perform(**base_opts, method: "GET") { |res|
          res[:props][:kubernetes] = res[:parsed]["gitVersion"]
          res[:props][:major] = res[:parsed]["major"]
          res[:props][:minor] = res[:parsed]["minor"]
          res[:props][:build_date] = res[:parsed]["buildDate"]
        }
      end

      def self.access_heapster(base_opts, opts)
        populate("/namespaces/<project_name>/services/https:heapster:/proxy/api/v1/model/metrics", base_opts, opts)
        base_opts[:headers].delete("Accept") unless opts[:keep_accept]
        return perform(**base_opts, method: "GET")
      end

      def self.access_pod_network_metrics(base_opts, opts)
        populate("/namespaces/<project_name>/services/https:heapster:/proxy/api/v1/model/namespaces/<project_name>/pods/<pod_name>/metrics/network/<type>", base_opts, opts)
        base_opts[:headers].delete("Accept") unless opts[:accept]
        return perform(**base_opts, method: "GET")
      end

      def self.delete_subresources_api(base_opts, opts)
        populate("/namespaces/<project_name>/<resource_type>/<resource_name>/status", base_opts, opts)
        return perform(**base_opts, method: "DELETE")
      end

      def self.get_subresources_status(base_opts, opts)
        populate("/namespaces/<project_name>/<resource_type>/<resource_name>/status", base_opts, opts)
        return perform(**base_opts, method: "GET")
      end

      def self.get_project_status(base_opts, opts)
        populate("/namespaces/<project_name>/status", base_opts, opts)
        return perform(**base_opts, method: "GET")
      end

      def self.replace_pod_status(base_opts, opts)
        base_opts[:payload] = File.read(opts[:payload_file])
        populate("/namespaces/<project_name>/pods/<pod_name>/status", base_opts, opts)
        return Http.request(**base_opts, method: "PUT")
      end

      # make a request to the application running on the resource through
      # kubernetes proxy api
      def self.proxy_get_request_to_resource(base_opts, opts)
        populate("/namespaces/<project_name>/<resource_type>/<protocol_type>:<resource_name>:<port_name>/proxy#{opts[:app_path]}", base_opts, opts)
        return perform(**base_opts, method: "GET")
      end

      def self.create_pod_eviction(base_opts, opts)
        base_opts[:payload] = File.read(expand_path(opts[:payload_file]))
        populate("/namespaces/<project_name>/pods/<pod_name>/eviction", base_opts, opts)
        return perform(**base_opts, method: "POST")
      end

      def self.view_metering_report(base_opts, opts)
        populate("/namespaces/<project_name>/services/https:reporting-operator:http/proxy/api/v1/reports/get?name=<name>&format=<report_format>", base_opts, opts)
        return perform(**base_opts, method: "GET")
      end

    end
  end
end
