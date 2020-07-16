#!/usr/bin/env ruby
require 'net/ssh'
require 'net/ssh/proxy/jump'
require 'net/ssh/proxy/command'
require 'net/scp'
require 'fileutils'

module BushSlicer
  module SSH
    module Helper
      # generate a key pair mainly useful for SSH but can be generic
      # will monkey patch a method to get public key in proper String format
      def self.gen_rsa_key(len=2048)
        key = OpenSSL::PKey::RSA.generate(len)
        key.singleton_class.class_eval do
          def to_pub_key_string
            ::BushSlicer::SSH::Helper.to_pub_key_string(self)
          end
        end

        return key
      end

      def self.to_pub_key_string(key)
        "#{key.ssh_type} #{[ key.to_blob ].pack('m0')}"
      end
    end

    # represent a running ssh command
    class Command
      include Common::Helper

      attr_reader :opts, :connection, :channel, :started_at

      def initialize(command, connection, **opts)
        # TODO: use shell service for greater flexibility and interactiv cmds
        #       http://net-ssh.github.io/ssh/v1/chapter-5.html
        # TODO: allow setting environment variables via channel.env
        raise "setting env variables not implemented yet" if opts[:env]

        @res_lock = Mutex.new
        @connection = connection
        @opts = opts
        @result = opts[:result] || {}
        result[:timeout] = false
        result[:channel_object] = self
        result[:command] = command
        instruction = 'Remote cmd: `' + command + '` @ssh://' +
                      ( user ? "#{user}@#{host}" : host )
        result[:instruction] = instruction
        logger.info(instruction) unless opts[:quiet]
        stdout = result[:stdout] = opts[:stdout] || String.new
        if opts[:stderr] == :stderr
          stderr = result[:stderr] = String.new
        else
          stderr = result[:stderr] = opts[:stderr] || stdout
        end

        @started_at = Time.now
        @channel = connection.session.open_channel do |channel|
          channel.exec(command) do |ch, success|
            result { |r| r[:success] = success }
            unless success
              err = "could not execute command on #{host}: #{command}"
              logger.error(err)
              result[:error] = RuntimeError.new(err)
              result[:error].set_backtrace(Thread.current.backtrace)
              abort
            end

            channel.on_data do |ch,data|
              stdout << data
            end

            channel.on_extended_data do |ch,type,data|
              stderr << data
            end

            channel.on_request("exit-status") do |ch,data|
              result[:exitstatus] = data.read_long
              fail! if result[:exitstatus] != 0
            end

            channel.on_request("exit-signal") do |ch, data|
              result[:exitsignal] = data.read_long
              fail!
            end

            case opts[:stdin]
            when :empty, ":empty"
              keep_stdin_open = true
            else
              channel.send_data opts[:stdin].to_s
            end

            channel.eof! unless keep_stdin_open
          end
        end

        # needs to be outside new channel block as it needs to be registered
        #   before channel is opened
        @channel.on_open_failed do |ch, code, desc|
          fail!
          err = "could not open SSH channel on #{host}: #{code} #{desc}"
          logger.error(err)
          result[:error] = RuntimeError.new(err)
          result[:error].set_backtrace(Thread.current.backtrace)
        end
      end

      # wait for command to be started on the remote host; this will not wait
      #   command completion
      def wait_exec
        wait_for(20) {
          # channel.active?
          result { |r| r.has_key? :success }
        }
        unless result.has_key? :success
          raise BushSlicer::TimeoutError, "timeout waiting for command to start exution"
        end
      end

      def fail!
        result { |r| r[:success] = false }
      end

      def result
        if block_given?
          @res_lock.synchronize { yield @result }
        else
          @result
        end
      end

      def running?
        channel.active? && !channel.connection.closed?
      end

      def close
        channel.close
      end

      # @return [ResultHash]
      def wait
        # wait channel to finish; nil or 0 means no timeout (wait forever)
        wait_since = monotonic_seconds - (Time.now - started_at)
        while opts[:timeout].nil? ||
              opts[:timeout] == 0 ||
              monotonic_seconds - wait_since < opts[:timeout]
          # checking session for https://github.com/net-ssh/net-ssh/issues/425
          break unless running?
          # break unless active_recently_verified? # useless with keepalive
          sleep 1
        end
        if channel.active?
          fail! # timeout of connection premature close
          if channel.connection.closed?
            # looks like session closed before channel finished
            # I don't think liveness probe is likely to end-up here so
            #   don't perform special handling here for it.
            err = connection.send :error # #error not exposed to the public
            # err = "ssh session @#{host} closed prematurely: #{err.inspect}"
            result[:error] = err
          else
            # looks like we hit command timeout
            close
            if opts[:liveness]
              logger.warn("liveness check failed, may retry @#{host}: #{command}")
            else
              logger.error("ssh channel timeout @#{host}: #{command}")
            end
            result[:error] = BushSlicer::TimeoutError.new("ssh channel timeout @#{host}: #{command}")
          end
        end
        unless opts[:quiet]
          logger.plain(result[:stdout], false)
          logger.plain(result[:stderr], false) unless result[:stdout].equal?(result[:stderr])
          logger.info("Exit Status: #{result[:exitstatus]}")
        end

        return result
      end

      def user
        connection.user
      end

      def host
        connection.host
      end

      def inspect
        cmd = result[:command]
        cmd = "#{cmd[0..25]}.." if cmd.size > 25
        "#<BushSlicer::SSH::Command #{user}@#{host} #{cmd.inspect}>"
      end
    end

    class Connection
      include Common::Helper

      attr_reader :host, :user

      # @return [exit_status, output]
      def self.exec(host, cmd, opts={})
        ssh = self.new(host, opts)
        return ssh.exec(cmd)
      rescue => e
        # seems like connection initialization failed
        return { success: false,
                 instruction: "ssh #{opts[:user]}@#{host}",
                 error: e,
                 response: exception_to_string(e)
        }
      ensure
        ssh.close if defined?(ssh) and ssh
      end

      # @param [String] host the hostname to establish ssh connection
      # @param [Hash] opts other options
      # @note if no password and no private key are specified, we assume
      #   ssh is pre-configured to gain access
      def initialize(host, opts={})
        @host = host
        raise "ssh host is mandatory" unless host && !host.empty?

        @user = opts[:user] # can be nil for default username
        conn_opts = {keepalive: true}
        if opts[:jump]
          conn_opts[:proxy] = Net::SSH::Proxy::Jump.new(opts[:jump])
        elsif opts[:proxy]
          conn_opts[:proxy] = Net::SSH::Proxy::Command.new(opts[:proxy])
        end
        if opts[:private_key]
          logger.debug("SSH Authenticating with publickey method")
          private_key = expand_private_path(opts[:private_key])
          # this is not needed for ruby but help ansible and standalone ssh
          File.chmod(0600, private_key) rescue nil
          conn_opts[:keys] = [private_key]
          conn_opts[:auth_methods] = ["publickey"]
        elsif opts[:password]
          logger.debug("SSH Authenticating with password method")
          conn_opts[:password] = opts[:password]
          conn_opts[:auth_methods] = ["password"]
        else
          ## lets hope ssh is already pre-configured
          #logger.error("Please provide password or key for ssh authentication")
          #raise Net::SSH::AuthenticationFailed
        end
        begin
          @session = Net::SSH.start(host, user, **conn_opts)
        rescue Net::SSH::HostKeyMismatch => e
          raise e if opts[:strict]
          e.remember_host!
          retry
        end
        @last_accessed = monotonic_seconds
      end

      # closing underlying transport
      # @param [Integer] graceful seconds to wait for channels to finish before
      #   killing the processing thread and close the connection
      # @note that started processes are not killed unless they die because
      #   of stdin/out being closed when ssh connection dies
      def close(graceful: 15)
        # @session.close unless closed?
        unless closed?
          loop_thread_kill(graceful)
          @session.shutdown!
        end
      end

      def closed?
        return ! active?(verify: false)
      end

      def active?(verify: false)
        if @session && ! @session.closed?
          case
          when verify == :force
            do_verify
          when verify
            active_recently_verified?
          else
            true
          end
        else
          false
        end
      end

      # make sure connection was recently enough actually usable;
      #   otherwise perform a simple connection test;
      #   this is useful with keepalive: true when the host reboots
      private def active_recently_verified?
        case
        when @last_accessed.nil?
          raise "ssh session initialization issue, we should never be here"
        when monotonic_seconds - @last_accessed < 120 # 2 minutes
          return true
        else
          return do_verify
        end
      end

      private def do_verify
        res = exec("echo", timeout: 30, liveness: true)
        if res[:success]
          @last_accessed = monotonic_seconds
          return true
        else
          return false
        end
      end

      def session
        # the assumption is that if somebody gets session, he would also call
        # something on it. So if a command or file transfer or something is
        # called then operation on success will prove session alive or will
        # cause session to show up as closed. If that assumption proves wrong,
        # we may need to find another way to update @last_accessed, perhaps
        # only inside methods that really prove session is actually alive.
        @last_accessed = monotonic_seconds
        return @session
      end

      # TODO: unify with [Command#wait]
      private def wait_scp(channel)
        success = true
        # FYI I think SSH gem is not solid for multi-threading
        # what if channel fails before we havea chance to register
        #   `on_open_failed` hook?
        # one remedy could be to stop loop thread while creating a channel
        channel.on_open_failed do |ch, code, desc|
          success = false
          err = "could not open SSH channel on #{host}: #{code} #{desc}"
          logger.error(err)
        end
        loop_thread!

        closed = wait_for(3600) do
          !channel.active? || channel.connection.closed?
        end

        if closed && channel.active?
          logger.error self.error
        elsif closed
          return
        else
          logger.error "SCP timeout"
        end
      rescue Net::SCP::Error => e
        logger.error e
        # we can reconsider dismissing such errors
      end

      # @param [String] local the local filename to upload
      # @param [String] remote the directory, where to upload
      def scp_to(local, remote)
        wait_scp \
          session.scp.upload(local, remote, :recursive=>true, preserve: true)
      end

      # @param [String] remote the absolute path to be copied from
      # @param [String] local directory
      def scp_from(remote, local)
        FileUtils.mkdir_p local
        wait_scp \
          session.scp.download(remote, local, :recursive=>true, preserve: true)
      end

      def exec(command, opts={})
        # we want to have a handle over the result in case of error occurring
        # so that we catch any intermediate data for better reporting
        res = opts[:result] || {}

        # now actually execute the ssh call
        begin
          exec_raw(command, **opts, result: res)
        rescue => e
          res[:success] = false
          res[:error] = e
          res[:response] = exception_to_string(e)
        end
        if res[:stdout].equal?(res[:stderr]) || res[:stderr].to_s.empty?
          output = res[:stdout]
        else
          output = "STDOUT:\n#{res[:stdout]}\nSTDERR:\n#{res[:stderr]}"
        end
        if res[:response]
          # i.e. an error was raised durig the call
          res[:response] = "#{output}\n#{res[:response]}"
        else
          res[:response] = output
        end

        return res
      end

      # TODO: use shell service for greater flexibility and interactive commands
      #       http://net-ssh.github.io/ssh/v1/chapter-5.html
      # TODO: allow setting environment variables via channel.env
      def exec_raw(command, opts={})
        raise "setting env variables not implemented yet" if opts[:env]

        background = opts.delete(:background)

        cmd = Command.new(command, self, **opts)
        loop_thread!
        cmd.wait_exec

        if background
          return cmd.result
        else
          return cmd.wait
        end
      end

      # launches a new loop/process thread unless we have one already running
      def loop_thread!
        unless @loop_thread && @loop_thread.alive?
          # session.loop is slow to pick-up new channels, also will exit when
          # no active channels are present and I'm not sure how this can
          # affect session close
          # @loop_thread = Thread.new { session.loop(1) {|s| s.busy?(include_invisible=true)} }
          @loop_thread = Thread.new {
            begin
              loop { session.process(1) }
            rescue => e
              # NET::SSH high level API is not very suitable for multi-streams.
              # One can register `on_open_failed` hook only after channel is
              # created. If the loop thread is running at that time, the
              # channel may fail earlier than the hook is registered.
              # For the time being, lets log the errors we see. We can patch
              # NET::SSH and NET::SCP upsteam to allow setting the hook
              # upon stream creation. After that we would be able to catch
              # errors per individual channels.
              if session.closed?
                logger.error "SSH IO thread quit due to: #{e.inspect}"
                raise e
              else
                logger.error "SSH IO thread error!"
                logger.error e
                retry
              end
            end
          }
          @loop_thread.name = "SSH-#{user}@#{host}"
        end
      end

      private def loop_thread_error
        # should we protect agains replacing dead thread before error is read?
        if @loop_thread && !@loop_thread.alive?
          begin
            @loop_thread.join
          rescue => e
            return e
          end
        end
        return nil
      end
      alias error loop_thread_error

      private def loop_thread_kill(timeout=15)
        if @loop_thread && @loop_thread.alive?
          success = wait_for(timeout) {
            session.channels.values.none? {|c| c.active?}
          }
          unless success
            logger.warn "Closing some active SSH channels for #{user}@#{host}"
          end
          @loop_thread.report_on_exception = false
          @loop_thread.kill
        end
      end
    end
  end
end
