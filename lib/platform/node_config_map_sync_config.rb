module BushSlicer
  module Platform
    # handles the fact node config is synced with a config map in 3.10
    class NodeConfigMapSyncConfig
      attr_reader :simple_config, :service
      private :simple_config

      def initialize(service)
        @service = service
        @simple_config = SimpleServiceYAMLConfig.new(
          service,
          "/etc/origin/node/node-config.yaml"
        )
        @sync_permitted = true
      end

      def merge!(yaml)
        sync_stop!
        simple_config.merge!(yaml)
      end

      def restore
        simple_config.restore
        sync_start!
      end

      def apply
        simple_config.apply
      end

      def as_hash
        simple_config.as_hash
      end

      private def sync_daemon_set
        @sync_daemon_set ||= DaemonSet.new(
          name: "sync",
          project: Project.new(name: "openshift-node", env: service.env)
        )
      end

      # @param labels [Hash<String, String>]
      private def patch_daemon_set(labels)
        patch = [{
          "op" => "add",
          "path" => "/spec/template/spec/nodeSelector",
          "value" => labels,
        }]
        res = service.env.admin.cli_exec(
          :patch,
          resource: sync_daemon_set.class::RESOURCE,
          resource_name: sync_daemon_set.name,
          n: sync_daemon_set.project.name,
          type: "json",
          p: patch.to_json
        )
        unless res[:success]
          raise "cound not patch daemonset node selector, see log"
        end
        # delete pods to enforce the change
        # countrary to docs, pods seem to be removed by patch alone
        #pods = sync_daemon_set.pods(user: service.env.admin, cached: false)
        #unless pods.empty?
        #  res = service.env.admin.cli_exec(
        #    :delete,
        #    object_type: Pod::RESOURCE,
        #    object_name_or_id: pods.map(&:name)
        #  )
        #  unless res[:success]
        #    raise "cound not delete daemonset pods, see log"
        #  end
        #end
      end

      protected def sync_permitted?
        @sync_permitted
      end

      protected def node_selector_orig
        @node_selector_orig
      end

      protected def node_selector_orig=(value)
        @node_selector_orig ||= value
      end

      private def sync_permitted_by_all?
        service.env.nodes.all? { |n| n.service.config.sync_permitted? }
      end

      private def set_node_selector_orig_for_all
        return if node_selector_orig
        selector = sync_daemon_set.node_selector(
          user: service.env.admin,
          cached: false
        )
        service.env.nodes.each { |node|
          node.service.config.node_selector_orig = selector
        }
      end

      private def sync_start!
        unless sync_permitted?
          # only try to start sync if we had changes
          @sync_permitted = true
          patch_daemon_set(node_selector_orig) if sync_permitted_by_all?
        end
      end

      private def sync_stop!
        if sync_permitted_by_all?
          # sync should be running ATM
          set_node_selector_orig_for_all
          patch_daemon_set({"disabled" => "for-testing"})
        end
        @sync_permitted = false
      end
    end
  end
end
