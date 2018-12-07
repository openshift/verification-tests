module VerificationTests
  module Platform
    # a file with backup on modification so it can be restored later
    class RestorableFile

      attr_accessor :host, :config_file_path
      attr_writer :config_modified

      private :config_modified=

      def initialize(host, file_path)
        @host = host
        @config_file_path = file_path
        self.config_modified = false
      end

      def exists?
        host.file_exist?(config_file_path)
      end

      def bak_exists?
        host.file_exist?(config_file_path_bak)
      end

      def config_modified?
        @config_modified
      end
      alias modified? config_modified?

      def config_file_path_bak
        "#{config_file_path}.bak"
      end

      def raw
        read_file(config_file_path)
      end


      def self.res_err_check(res, custom_err = false)
        unless res[:success]
          raise res[:error] if res.key?(:error)
          raise custom_err if custom_err
          raise res[:stderr]
        end
      end

      def update(content)
        backup unless bak_exists?
        write_file(config_file_path, content)
        self.config_modified = true
      end

      # TODO: implement platform independent way
      # @return [String] content of file
      private def read_file(path)
        res = host.exec_admin("cat #{host.shell_escape path}")
        self.class.res_err_check(res)
        return res[:response]
      end

      # TODO: implement platform independent way
      private def write_file(path, content)
        res = host.exec_admin(
          "cat > #{host.shell_escape path}", stdin: content
        )
        self.class.res_err_check(res)
      end

      # TODO: implement platform independent way
      private def copy_file(src, dst)
        res = host.exec_admin(
          "cp -aZ #{host.shell_escape src} #{host.shell_escape dst}"
        )
        self.class.res_err_check(res)
      end

      # TODO: implement platform independent way
      # @note Host#delete doesn't necessarily run as admin
      private def delete_file(path)
        res = host.exec_admin("rm #{host.shell_escape path}")
        self.class.res_err_check(res)
      end

      private def backup()
        return if bak_exists?
        copy_file(config_file_path, config_file_path_bak)
      end

      def restore()
        return unless config_modified?
        copy_file(config_file_path_bak, config_file_path)
        delete_file(config_file_path_bak)
        self.config_modified = false
      end
    end
  end
end
