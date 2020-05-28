require 'fileutils'
require 'shellwords'

require 'common'
require 'net'
require 'ssh'

module BushSlicer
  # @note a generic machine; base for creating actual implementations
  class Host
    include Common::Helper

    attr_reader :hostname

    # @param hostname [String] that test machine can access the machine with
    # @param opts [Hash] any other options relevant to implementation
    def initialize(hostname, opts={})
      if hostname.kind_of? String
        @hostname = hostname.dup.freeze
      else
        raise "Hostname must be a string, not #{hostname.inspect}"
      end
      @properties = opts.dup
      @workdir = opts[:workdir] ? opts[:workdir].dup.freeze : "/tmp/workdir/" + EXECUTOR_NAME
    end

    # @param ip [String] string representation of IP address
    # @param opts [Hash] host options, should contain :class to speciy
    #   the Host sub-class to instantiate
    # @return [Host] object of kind as specified by opts[:class] option
    def self.from_ip(ip, opts)
      clz = opts[:class] || raise("need to know class to instantiate Host")
      hostname = Common::Net.reverse_lookup ip
      return BushSlicer.const_get(clz).new(hostname, **opts, ip: ip)
    end

    def self.from_hostname(hostname, opts)
      clz = opts[:class] || raise("need to know class to instantiate Host")
      return BushSlicer.const_get(clz).new(hostname, opts)
    end

    def self.localhost
      @localhost if @localhost
      @localhost ||= case RUBY_PLATFORM
      when /linux/, /darwin/   # for Mac it's darwin
        LocalLinuxLikeHost.new(nil)
      else
        raise "don't know a suitable host for your platform"
      end
    end

    private def properties
      @properties
    end

    def [](key)
      properties[key]
    end

    def []=(key, value)
      properties[key] = value
    end

    # override for hosts that can be accessed (ssh, remote desctop, etc.)
    def accessible?
      return {
        success: false,
        instruction: "access host noop",
        error: nil,
        response: ""
      }
    end

    # @param timeout [Integer, String] seconds
    def wait_to_become_accessible(timeout)
      res = nil
      wait_for(Integer(timeout)) {
        res = accessible?
        res[:success]
      }
      unless res[:success]
        logger.warn res[:response]
        raise res[:error] rescue raise(
          BushSlicer::TimeoutError,
          "#{self} did not become available within #{timeout} seconds"
        )
      end
      return res
    end

    def workdir(**opts)
      unless @workdir_exists
        mkdir(@workdir, :raw => true)
        @workdir_exists = true
      end
      if ! opts[:absolute] || ["/", "\\"].include?(@workdir[0])
        return @workdir
      else
        return @workdir_abs ||= File.absolute_path(@workdir, pwd)
      end
    end

    # @return [String] absolute path
    def absolutize(path, raw: false)
      if path.start_with?("/", "\\")
        return path
      elsif raw
        File.absolute_path(path, pwd)
      else
        return File.absolute_path(path, workdir(absolute: true))
      end
    end

    # @return pwd of raw commands executed on the host
    private def pwd
      raise "#{__method__} method not implemented"
    end

    # @ param [String] path the path to convert to an absolute path
    # @return expanded path with workdir as basedir; IO might not be done so
    #   workdir may not exist after the call; if absolute, path is returned
    #   intact
    def absolute_path(path, **opts)
      if ["/", "\\"].include? path[0]
        return path
      elsif opts[:raw]
        return File.absolute_path(path, pwd)
      else
        ws_abs_path = ["/", "\\"].include?(@workdir[0]) ? @workdir : workdir(absolute: true)
        return File.absolute_path(path, ws_abs_path)
      end
    end

    def roles
      @properties[:roles] ||= []
    end

    def has_role?(role)
      roles.include? role
    end

    def has_any_role?(test_roles)
      !has_none_of_roles?(test_roles)
    end

    def has_none_of_roles?(test_roles)
      (roles & test_roles).empty?
    end

    def has_all_roles?(test_roles)
      (test_roles - roles).empty?
    end

    def has_hostname?
      # TODO: support IPv6 /\A(?:[0-9.]+|[0-9a-f:]+)\z/ or IPAddr class
      ! (hostname =~ /\A[0-9.]+\z/)
    end

    # discouraged, used for updating hosts that did not have a hostname initially
    def update_hostname(hostname)
      @hostname = hostname
    end

    # escape characters for use as command arguments
    def shell_escape(str)
      raise "#{__method__} method not implemented"
    end

    def exec_checked(*commands, **opts)
      res = exec(*commands, **opts)
      if res[:success]
        return res
      else
        raise "command exited with #{res[:exitstatus]}:\n#{res[:response]}"
      end
    end

    # @param commands [Array<String>] the commands to be executed
    # @param opts [Hash] host executor options, e.g. :chdir, :single,
    #   :background, etc.
    def exec(*commands, **opts)
      exec_as(nil, *commands, **opts)
    end

    # @see #exec with the only difference we run as host admin user
    def exec_admin(*commands, **opts)
      exec_as(:admin, *commands, **opts)
    end

    # @see #exec with the only difference we run as anothr user
    def exec_as(user, *commands, **opts)
      raise "#{__method__} method not implemented"
    end

    # @exec exec without any preparations like chdir
    def exec_raw(*commands, **opts)
      raise "#{__method__} method not implemented"
    end

    # @note execute process in the background and inserts clean-up hooks
    def exec_background_as(user, *commands, **opts)
      raise "#{__method__} method not implemented"
    end

    def exec_background(*commands, **opts)
      exec_background_as(nil, *commands, **opts)
    end

    def exec_background_admin(*commands, **opts)
      exec_background_as(:admin, *commands, **opts)
    end

    # @param spec - interaction specification
    # @param opts [Hash] additional options
    def exec_interactive(spec, **opts)
      exec_interactive_as(nil, spec, **opts)
    end

    def exec_interactive_admin(spec, **opts)
      exec_interactive_as(:admin, spec, **opts)
    end

    def exec_interactive_as(user, spec, **opts)
      raise "#{__method__} method not implemented"
    end

    def copy_to(local_file, remote_file, opts={})
      raise "#{__method__} method not implemented"
    end

    def copy_from(remote_file, local_file, opts={})
      raise "#{__method__} method not implemented"
    end

    # @return false if dir exists and raise if cannot be created
    def mkdir(remote_dir, opts={})
      raise "#{__method__} method not implemented"
    end

    def touch(file, opts={})
      raise "#{__method__} method not implemented"
    end

    # @return false on unsuccessful deletion
    def delete(file, opts={})
      raise "#{__method__} method not implemented"
    end

    # @return file name of first file found
    def wait_for_files(*files, **opts)
      raise "#{__method__} method not implemented"
    end

    # @return String local ip based on default route
    def local_ip
      properties[:local_ip] ||= get_local_ip_platform
    end

    # @param value [String]
    def local_ip=(value)
      properties[:local_ip] = value
    end

    def local_hostname
      properties[:local_hostname] ||= get_local_hostname_platform
    end

    private def get_local_hostname_platform
      raise "#{__method__} method not implemented"
    end

    # see #local_ip
    private def get_local_ip_platform
      raise "#{__method__} method not implemented"
    end

    # @return ip based on [#hostname] string
    def ip
      @ip ||= self[:ip] || Common::Net.dns_lookup(hostname)
    end

    def clean_up
      if @workdir_exists
        @workdir_exists = ! delete(@workdir, :r => true, :raw => true)
      end
    end

    # @param key [STRING] if you perform multiple unrelated setup operations on host, this param lets framework distinguish between lock directories
    # @note convenience to perform setup on a host
    def setup(key="SETUP")
      raise "provide setup code in a block" unless block_given?

      if setup_lock(key)
        # we have the lock, lets perform setup
        begin
          yield
          setup_lock_clear(key)
        rescue Exception => e
          setup_lock_clear(key, false)
          raise e
        end
      else
        # wait for another bushslicer instance to perform broker setup
        unless setup_lock_wait(key)
          raise "setup of broker failed on another runner, see its logs or clear it by removing the directory /root/broker_setup from the devenv"
        end
      end
    end

    # set setup lock on this broker instance
    private def setup_lock(key)
      return mkdir("bushslicer_lock_#{key}", :raw => true, :parents => false)
    end

    # clear setup lock for this instance
    private def setup_lock_clear(key, success=true)
      touch("bushslicer_lock_#{key}/#{success ? 'DONE' : 'FAIL'}", :raw => true)
      # ret_code, msg = ssh.exec("touch broker_setup/#{success ? 'DONE' : 'FAIL'}")
    end

    # wait until setup lock is cleared or status is fail
    private def setup_lock_wait(key)
      file = wait_for_files("bushslicer_lock_#{key}/DONE", "bushslicer_lock_#{key}/FAIL", :raw => true)
      return file.include?("DONE")
      #ret_code, msg = ssh.exec('while sleep 1; do [ -f broker_setup/DONE ] && break; [ -f broker_setup/FAIL ] && exit 1; done')
      #return ret_code == 0
    end

    def to_s
      return self[:user].to_s + '@' + hostname
    end

    # @return [Integer] seconds since host has been started
    def uptime
      raise "#{__method__} method not implemented"
      # `awk -F . '{print $1}' /proc/uptime`
    end

    # @return [Time] host local time
    def time
      raise "#{__method__} method not implemented"
    end

    def reboot
      raise "#{__method__} method not implemented"
    end

    def reboot_checked(timeout:)
      before_reboot = time
      reboot
      sleep 30 # let machine enough time to actually reboot
      wait_to_become_accessible(timeout)
      if before_reboot < time - uptime
        return nil
      else
        raise BushSlicer::TimeoutError,
          "#{self} does not appear to have actually rebooted"
      end
    end

    # @param spec [String] comma separated list of host specifications which
    #   begins optionally with flags between slash `/` characters, followed by
    #   hostname and separated by colon `:` roles
    def self.from_spec(spec, **env_opts)
      hosts = spec.split(",").map do |host|
        flags = host.slice! %r{^/.*/}
        hostname, *roles = host.split(":")
        roles.map!(&:to_sym)
        self.new(hostname, **env_opts, roles: roles, flags: flags)
      end
      return hosts
    end

    def apply_flags(other_hosts)
      if self[:flags] and !self[:flags].empty?
        raise "flags '#{self[:flags]}' not supported by #{self.class}"
      end
    end
  end

  class LinuxLikeHost < Host
    private def get_local_hostname_platform
      res = exec_raw('hostname')
      if res[:success]
        return res[:response].strip
      else
        logger.error(res[:response])
        raise "can not get local hostname"
      end
    end

    private def get_src_ip(destination_ip)
      res = exec_admin("ip route get '#{destination_ip}' | sed -rn 's/^.*src (([0-9]+\.?){4}|[0-9a-f:]+).*/\\1/p'", stderr: :stderr)
      if res[:success]
        return res[:stdout].strip
      else
        logger(res[:response])
        raise "cannot get src ip for destination '#{destination_ip}'"
      end
    end

    # see #local_ip
    private def get_local_ip_platform
      get_src_ip("10.10.10.10")
    end

    # @return String empty if could not resolve
    private def dns_resolve(host_or_ip)
      res = exec("getent ahosts '#{host_or_ip}' | awk '{print $1; exit}'")
      if res[:success]
        return res[:response].strip
      else
        logger(res[:response])
        raise "cannot get src ip for destination '#{host_or_ip}'"
      end
    end

    def local_ip?(host_or_ip)
      # I think src ip approach is more reliable than hostname checking
      # if local_hostname == host_or_ip
      #   return true
      # else

      ip = dns_resolve host_or_ip
      raise "unknown host '#{host_or_ip}'" if ip.empty?

      return ip == get_src_ip(ip)
    end

    def commands_to_string(*commands)
      return commands.flatten.join("\n")
    end

    def shell_escape(str)
      # basically single quote replacing occurances of `'` with `'\''`
      # return "'" << str.gsub("'") {|m| %q{'\''}} << "'"

      # escape nesting reads better with backslashes
      Shellwords.escape(str)
    end

    # @return pwd of raw commands executed on the host
    private def pwd
      res = exec_raw('pwd', quiet: true)
      unless res[:exitstatus] == 0
        logger.error(res[:stdout])
        logger.error(res[:stderr])
        raise "could not get pwd, see log"
      end

      return res[:stdout].strip
    end

    # @param [String] file check this file for existence
    def file_exist?(file, opts={})
      exec("ls -d #{shell_escape(file)}", **opts)[:success]
    end

    # @param [String, nil, :admin] user execute command as that OS user
    # @note executes commands on host in workdir
    def exec_as(user, *commands, **opts)
      case user
      when nil, self[:user]
        # perform blind exec in workdir
        return exec_raw("cd '#{workdir}'", commands, **opts)
      when :admin
        # try to use sudo
        # in the future we may use `properties` for different methods
        # we may also allow choosing shell
        # TODO: are we admins?
        if self[:user] == "root"
          return exec_as(nil, *commands, **opts)
        else
          cmd = "sudo bash -lc #{shell_escape(commands_to_string("cd #{shell_escape(workdir)}", commands))}"
          return exec_raw(cmd, **opts)
        end
      else # try sudo -u
        raise "username cannot be empty" if user.empty?
        cmd = "sudo -u #{user} bash -lc #{shell_escape(commands_to_string("cd #{shell_escape(workdir)}", commands))}"
        return exec_raw(cmd, **opts)
      end
    end

    # @return false if dir exists and raise if cannot be created
    def mkdir(remote_dir, opts={})
      parents = opts[:parents] || ! opts.has_key?(:parents) ? " -p" : ""
      if opts[:raw]
        res = exec_raw("mkdir -v#{parents} '#{remote_dir}'", **opts)
      else
        res = exec("mkdir -v#{parents} '#{remote_dir}'", **opts)
      end

      raise "error creating dir #{remote_dir}" unless res[:success]

      return res[:response].include? remote_dir
    end

    def touch(file, opts={})
      if opts[:raw]
        exec_raw("touch '#{file}'", opts)
      else
        exec("touch '#{file}'", opts)
      end
    end

    # @return false on unsuccessful deletion
    def delete(file, opts={})
      if opts[:r] || opts[:recursive]
        # make sure we do not cause catastrophic damage
        bad_files = ["/", "../", "./", "..", ".", "", nil, false]
        if bad_files.include? file
          raise "should not remove file named '#{file}'"
        end

        r = "-r"
      else
        r = ""
      end
      file = shell_escape file
      if opts[:home] && ! file.start_with?('/','\\')
        # relative to host local user home directory
        # relies strongly on bad_files checking above
        file = '~/' + file
      end
      if opts[:raw]
        exec_method = :exec_raw
      elsif opts[:admin]
        exec_method = :exec_admin
      else
        exec_method = :exec
      end
      public_send(exec_method, "rm #{r} -f -- #{file}", opts)
      opts[:quiet] = true
      res = public_send(exec_method, "ls -d -- #{file}", opts)

      # OCDebugAccessibleHost does not return exit status of executed command
      # return ! res[:success]
      return res[:response].include? "No such"
    end

    # wait until one file in the list is found and returns its name
    def wait_for_files(*files, **opts)
      conditions = [files].flatten.map { |f|
        "[ -f \"#{f}\" ] && echo FOUND FILE: && break\n"
      }.join

      cmd = "while sleep 1; do
               #{conditions}
             done"
      if opts[:raw]
        res = exec_raw(cmd)
      else
        res = exec(cmd)
      end

      return res[:response][/(?<=FOUND FILE: ).*(?=$)/]
    end

    # @return [Integer] seconds since host has been started
    def uptime
      cmd = "awk -F . '{print $1}' /proc/uptime"
      res = exec_raw(cmd, timeout: 20)
      if res[:success]
        return Integer(res[:stdout])
      else
        raise "failed to get #{self} uptime, see log"
      end
    end

    # @return [Time] host local time
    def time
      cmd = "date -u +%FT%TZ"
      # date -u +"%Y-%m-%dT%H:%M:%SZ"
      res = exec_raw(cmd, timeout: 20)
      if res[:success]
        # oc debug returns garbage from stderr
        # https://bugzilla.redhat.com/show_bug.cgi?id=1771549
        time = res[:response].match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/).to_s
        if time.empty?
          raise "could not find time string in output, see log"
        end
        return Time.iso8601(time)
      else
        raise "failed to get #{self} current time, see log"
      end
    end

    # @return [nil]
    # @raise [Error] when any error was detected
    def reboot
      cmd = 'shutdown -r now "BushSlicer triggered reboot"'
      res = exec_raw(cmd, timeout: 20)
      if res[:success]
        return nil
      else
        case res[:error]
        when IOError, BushSlicer::TimeoutError
          return nil
        when nil
          raise "failed execute \`#{cmd}\` on #{self} for an unknown reason"
        else
          raise "failed execute \`#{cmd}\` on #{self}, see log"
        end
      end
    end
  end

  # some pure-ruby method implementations
  module LocalHost
    def copy_to(local, remote, **opts)
      FileUtils.cp_r absolutize(local, raw: opts[:raw]),
                     absolutize(remote, raw: opts[:raw])
      # exec "cp", "-r", local, absolutize(remote, raw: opts[:raw])
    end

    def copy_from(remote, local, **opts)
      # exec "cp", "-r", remote, absolutize(local, raw: opts[:raw])
      FileUtils.cp_r absolutize(remote, raw: opts[:raw]),
                     absolutize(local, raw: opts[:raw])
    end
  end

  class LocalLinuxLikeHost < LinuxLikeHost
    include LocalHost

    def initialize(hostname, opts={})
      hostname ||= self.hostname
      super

      # figure out workdir
      # write everything to WORKSPACE on jenkins, otherwise use `~/workdir`
      # on localhost, usage of relative workspace path may cause trouble
      if ENV["WORKSPACE"]
        @workdir = File.join(ENV["WORKSPACE"], "workdir")
      else
        basepath = File.expand_path("~/workdir/")
        executor = properties[:workdir] ? properties[:workdir] : EXECUTOR_NAME
        @workdir = File.absolute_path(executor, basepath)
      end
      @workdir.freeze
    end

    def accessible?
      return {
        success: true,
        instruction: "access localhost",
        error: nil,
        response: ""
      }
    end

    def file_exist?(file, opts={})
      # intentionally use @workdir to avoid creating dir unnecessarily
      file = File.absolute_path(file, @workdir) unless opts[:raw]
      return File.exist?(file)
    end

    # Do not use unless absolutey sure what you are doing; we should usually
    #   sit inside workdir
    def chdir(dir=nil)
      Dir.chdir(dir || workdir)
    end

    def exec_raw(*cmds, **opts)
      background = opts.delete(:background)
      if opts.delete(:single) || cmds.size == 1
        cmd_spec = cmds
      else
        cmd_spec = commands_to_string(cmds)
      end

      process = LocalProcess.new(*cmd_spec, **opts)

      if background
        process.finished? || manager.temp_resources << process
        return process.result
      else
        return process.wait
      end
    end

    def exec_as(user, *commands, **opts)
      case user
      when nil, self[:user]
        # perform blind exec in workdir
        return exec_raw(*commands, chdir: workdir, **opts)
      else
        super
      end
    end

    # @note execute process in the background and inserts clean-up hooks
    def exec_background_as(user, *commands, **opts)
      exec_as(user, *commands, background: true, **opts)
    end

    # TODO: implement delete, mkdir, touch in ruby in the LocalHost module

    def clean_up
      chdir(HOME)
      super
    end

    def hostname
      HOSTNAME
    end
  end

  class SSHAccessibleHost < LinuxLikeHost
    # @return [boolean] if there is currently an active connection to the host
    private def connected?(verify: false)
      @ssh && @ssh.active?(verify: verify)
    end

    # unlike #connected?, this method will always issue a test command to verify
    # remote host is accessible at the moment
    def accessible?
      res = {
        success: false,
        error: nil,
        response: ""
      }
      res[:instruction] = "ssh #{self.inspect}"
      res[:success] = connected?(verify: :force) || !!ssh
    rescue => e
      res[:error] = e
      res[:response] = exception_to_string(e)
    ensure
      return res
    end

    # processes ssh specific opts from the initialization options
    protected def ssh_opts(additional_opts={})
      ssh_opts = {}
      properties.each { |prop, val|
        if prop.to_s.start_with? 'ssh_'
          ssh_opts[prop.to_s.gsub(/^ssh_/,'').to_sym] = val
        elsif prop == :user
          ssh_opts[:user] = val
        end
      }
      ssh_opts.merge! additional_opts

      return ssh_opts
    end

    # @return [String] host line suitable for use in ansible inventory
    def ansible_host_str(admin: true)
      sshopts = ssh_opts
      str = hostname.dup
      if sshopts[:user]
        str << ' ansible_user=' << sshopts[:user]
        # stay compatible with ansible 1.9
        str << ' ansible_ssh_user=' << sshopts[:user]
        if admin && sshopts[:user] != "root"
          str << " ansible_become=yes"
        end
      end
      if sshopts[:private_key]
        # we chmod ssh key upon ssh to machine, but make sure it is done
        #   before we run ansible (e.g. we never sshed to host before that)
        ssh_key = expand_private_path(sshopts[:private_key])
        File.chmod(0600, ssh_key) rescue nil
        str << ' ansible_ssh_private_key_file="' << ssh_key << '"'
      end
      if sshopts[:password]
        pswd = sshopts[:password].gsub('"','\\"')
        str << ' ansible_ssh_pass="' << pswd << '"'
      end
      return str
    end

    private def ssh(opts={})
      return @ssh if connected?(verify: true)
      return @ssh = SSH::Connection.new(hostname, ssh_opts(opts))
    end

    # @note execute commands without special setup
    def exec_raw(*commands, **opts)
      ssh(opts).exec(commands_to_string(commands),opts)
    end

    def copy_to(local, remote, **opts)
      ssh.scp_to Host.localhost.absolutize(local, raw: opts[:raw]),
                 absolutize(remote, raw: opts[:raw])
    end

    def copy_from(remote, local, **opts)
      ssh.scp_from absolutize(remote, raw: opts[:raw]),
                   Host.localhost.absolutize(local, raw: opts[:raw])
    end

    def apply_flags(other_hosts)
      if self[:flags] == "/b/"
        # setup bastion host
        bastion = select_bastion(other_hosts)
        if bastion.ssh_opts[:user]
          bastion_connect_str = "#{bastion.ssh_opts[:user]}@#{bastion.hostname}"
        else
          bastion_connect_str = bastion.hostname
        end

        # setup proxy/jump/bastion host
        bastion_key = bastion.ssh_opts[:private_key]
        if bastion_key
          key_str = "-i #{Host.localhost.shell_escape(expand_private_path(bastion_key))}"
        end
        self[:ssh_proxy] = "ssh -o StrictHostKeyChecking=no -W %h:%p #{key_str} #{bastion_connect_str}"
        # https://github.com/net-ssh/net-ssh/issues/653 jump lacks key setup
        # self[:ssh_jump] = bastion_connect_str
      elsif self[:flags] and !self[:flags].empty?
        raise "flags '#{self[:flags]}' not supported by #{self}"
      end
    end

    private def select_bastion(hosts)
      hosts = hosts.select { |h| self.class === h }
      b = hosts.find {|h| h.roles.include?(:bastion)}
      unless b
        # select first master as a bastion host
        b = hosts.find { |h|
          h.roles.include?(:master) && !h[:flags]&.include?("/b/")
        }
        b.roles << :bastion
      end
      return b
    end

    private def close
      @ssh.close if @ssh
    end

    def clean_up
      return unless connected?
      super
      close
    end
  end

  class OCDebugAccessibleHost < LinuxLikeHost
    def initialize(hostname, opts={})
      super
      @workdir = "/tmp/workdir/" + EXECUTOR_NAME unless self[:workdir]
      @exec_lock = Mutex.new
    end

    private def service_project
      node.env.service_project
    end

    # @note execute commands without special setup
    def exec_raw(*commands, **opts)
      unless opts[:single]
        commands = ["chroot", "/host/", "bash", "-c", commands_to_string(commands)]
      end

      exec_opts = {}

      # override image, arg order matters, image needs to go before --
      # needed until https://bugzilla.redhat.com/show_bug.cgi?id=1728135 is fixed
      unless node.env.opts[:host_debug_image]
           mpods = Pod.get_labeled("app=multus", user: node.env.admin, project: Project.new(name: "openshift-multus", env: node.env), quiet: true)
           exec_opts[:image] = mpods.first.container(name: "kube-multus").spec.image
      end

      exec_opts.merge!(
          {
              resource: "node/#{node.name}",
              n: service_project.name,
              oc_opts_end: "",
              exec_command_arg: commands,
              _stdin: opts[:stdin],
              _stdout: opts[:stdout]
          }
      )

      @exec_lock.synchronize {
        # note this will block until timeout if command does not exist remotely
        # TODO: check debug pod status in the background to avoid freeze (WRKLDS-99)
        # note2: exit status is always 0 (WRKLDS-98)
        # note3: stdin and stderr come together (WRKLDS-110)
        node.env.admin.cli_exec(:debug, **exec_opts)
      }
    end

    def copy_to(local, remote, **opts)
      File.open(Host.localhost.absolutize(local, raw: opts[:raw]), "r") { |fd|
        res = exec_as(
          opts[:user],
          "cat > #{shell_escape absolutize(remote, raw: opts[:raw])}",
          stdin: fd,
        )

        unless res[:success]
          raise "failed to cat file to node, see log"
        end
      }
    end

    def copy_from(remote, local, **opts)
      File.open(Host.localhost.absolutize(local, raw: opts[:raw]), "w") { |fd|
        res = exec_as(
          opts[:user],
          "cat #{shell_escape absolutize(remote, raw: opts[:raw])}",
          stdout: fd
        )

        unless res[:success]
          raise "failed to cat file from node and write locally, see log"
        end
      }
    end

    def accessible?
      res = exec_raw("echo Smile more.")
      unless res[:response].include? "Smile more."
        res[:success] = false
      end
      return res
    end

    # @return [nil]
    # @raise [Error] when any error was detected
    # @note we do not check exit status due to the huge variety of possible
    #   error messages when node reboots while we are in `oc debug node`
    def reboot
      exec_raw('shutdown -r now "BushSlicer triggered reboot"', timeout: 20)
    end

    def node
      unless properties[:node]
        raise "Host object was not created with :node specified."
      end
      properties[:node]
    end

    def local_ip?(hostname_or_ip)
      hostname == hostname_or_ip
    end
  end
end
