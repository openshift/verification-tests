module BushSlicer
  module Platform
    class MasterScriptedStaticPodService < MasterService
      attr_reader :env

      def self.detected_on?(host)
        host.exec_admin("which master-restart")[:success]
      end

      def service
        unless @service
          @service = ScriptService.new(
            start: start_script,
            stop: stop_script,
            restart: restart_script,
            host: host,
            name: "atomic-master"
          )
        end
        return @service
      end

      private def components
        ["api", "controllers"]
      end

      private def pod_specs
        ["apiserver.yaml", "controller.yaml"]
      end

      private def start_script
        move_commands = pod_specs.map { |podfile|
          %{
          if [ -f /etc/origin/node/pods.bak/#{podfile} ]; then
            mv -v /etc/origin/node/pods.bak/#{podfile} /etc/origin/node/pods
          fi
          }
        }.join(" ")

        %{
        set -ex
        #{move_commands}
        }
      end

      private def stop_script
        move_commands = pod_specs.map { |podfile|
          %{
          if [ -f /etc/origin/node/pods/#{podfile} ]; then
            mv -v /etc/origin/node/pods/#{podfile} /etc/origin/node/pods.bak
          fi
          }
        }.join(" ")

        %{
        set -ex
        mkdir -p /etc/origin/node/pods.bak
        #{move_commands}
        }
      end

      private def restart_script
        %{
        set -ex
        if [ -f /etc/origin/node/pods.bak/#{pod_specs.first} ]; then
          #{start_script}
        else
          #{components.map { |c| "master-restart #{c}" }.join("\n")}
        fi
        }
      end
    end
  end
end
