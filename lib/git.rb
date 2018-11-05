module BushSlicer
  # let you operate a git repo
  class Git
    include Common::Helper
    attr_reader :host, :user

    # @param [String] uri remote git uri; when nil, checking the `origin` remote
    # @param [String] dir base directory of git repo;
    #   might be a relative to workdir or absolute path on host
    # @param [BushSlicer::Host] host the host repo is to be located
    # @param [String] user the host os user to run git as; usage is discouraged
    def initialize(uri: nil, dir: nil, host: nil, user: nil)
      @uri = uri
      @dir = dir
      @host = host || Host.localhost
      @user = user
      raise "need uri or dir" unless uri || dir
    end

    # basically we check directory exists as there is no good way to know
    #   whether what we expect is in there
    def cloned?(force: false)
      return @cloned if defined?(@cloned) && !force
      @cloned = host.file_exist?(dir)
      return @cloned
    end

    def dir
      @dir ||= File.basename(uri).gsub(/\.git$/,"")
    end

    def uri
      return @uri if @uri
      raise "need uri or dir but non are given" unless @dir

      res = host.exec_as(user, "git -C #{host.shell_escape dir} remote -v")
      if res[:success]
        @uri = res[:response].scan(/origin\s(.+)\s+\(fetch\)$/)[0][0]
      end

      unless @uri
        logger.info(res[:response])
        raise "cannot find out repo uri in git output"
      end

      return @uri
    end

    # execute commands in repo
    def exec(*cmd)
      unless cloned?
        raise "could not clone repo, see log" unless clone[:success]
      end

      res = host.exec_as(user, "cd #{host.shell_escape dir}", *cmd)

      unless res[:success]
        logger.info(res[:response])
        raise "failed to execute command in git repo"
      end

      return res
    end

    # clone a git repo
    def clone
      clone_cmd = "git clone #{host.shell_escape @uri} #{host.shell_escape dir}"
      res = host.exec_as(user, clone_cmd)
      # don't want to reset cloned status after it is once set
      @cloned = @cloned || res[:success]
      set_git_config
      return res
    end

    def set_git_config
      res = host.exec_as(user, "git -C #{dir} config user.name")
      unless res[:success]
        res = host.exec_as(user, "git -C #{dir} config user.name #{host.shell_escape 'BushSlicer User'}")
        unless res[:success]
          raise "git config user.name failed"
        end
      end
      res = host.exec_as(user, "git -C #{dir} config user.email")
      unless res[:success]
        res = host.exec_as(user, "git -C #{dir} config user.email #{host.shell_escape 'cucushift@example.com'}")
        unless res[:success]
          raise "git config user.email failed"
        end
      end
    end

    def status
      res = exec("git status")
      res[:clean] = res[:response].include?("working directory clean")
    end

    def add(*files, **opts)
      if opts[:all]
        exec "git add -A"
      else
        files.map!{|f| host.shell_escape(f)}
        exec "git add #{files.join(" ")}"
      end
    end

    def commit(**opts)
      msg = opts[:msg] || "new commit"
      if opts[:amend]
        raise "TODO: implement git amend"
        exec "git commit --amend ???"
      else
        exec "git commit -m #{host.shell_escape(msg)}"
      end
    end

    # @param [Boolean] new_file should we add a dummy file to push
    def push(force: false, all: true, branch_spec:nil, new_file: true, commit:"new commit")
      force = force ? " -f" : " "
      add(all: true) if all
      branch_spec ||= "HEAD"
      if new_file && status[:clean]
        file = "dummy.#{rand_str(4)}"
        exec("touch #{file}")
        add(file)
      end
      commit
      exec "git push#{force}#{branch_spec}"
    end

    # @param [Boolean], get the commit id from remote or local repo
    def get_latest_commit_id(**opts)
      if ! opts[:force_remote] && cloned?
        # res = exec "git log --format=\"%H\" -n 1"
        res = exec "git rev-parse HEAD"
      else
        res = host.exec_as(user, "git ls-remote #{host.shell_escape uri} HEAD")
      end

      raise "Can't get git commit id" unless res[:success]
      return res[:response].split(' ')[0].strip()
    end

    # @param [String], the remote tracked repo to delete from the local repo
    def remove_remote(remote)
      raise "No git remote specified to remove" unless remote
      exec "git remote remove #{remote}"
    end

    # @param [Hash<String, String>] the key/value pairs to set
    def set_global_config(hash)
      hash.each do |key, value|
        exec "git config --global #{host.shell_escape key}" \
         " #{host.shell_escape value}"
      end
    end
  end
end
