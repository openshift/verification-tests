# frozen_string_literal: true

require "stomp"
require "json"
require 'io/console' # for reading password without echo
require 'securerandom' # for generating UUID
require 'timeout' # to avoid freezes waiting for user input

require_relative "../common/load_path"
require 'common'

class STOMPBus
  include VerificationTests::Common::Helper

  LOGIN_OPTS = [[:login, :passcode], [:cert_file, :key_file]].freeze
  REQUIRED_HOST_OPTS = [:host, :port].freeze
  HOST_OPTS = ([:ssl, :ts_files, :key_password] +
               LOGIN_OPTS.flatten + REQUIRED_HOST_OPTS).freeze
  SSL_OPTS = [:ts_files, :cert_file, :key_file, :key_password]

  attr_reader :opts, :default_queue

  def initialize(**opts)
    pile_of_opts = {}
    pile_of_opts.merge! self.class.load_env_vars
    pile_of_opts.merge! opts

    service_name = pile_of_opts.delete(:service_name) || :stomp_bus
    service_opts = conf[:services, service_name]&.dup || {}
    service_hosts = service_opts.delete(:hosts)

    # see http://www.rubydoc.info/github/stompgem/stomp/Stomp/Client#initialize-instance_method
    default_opts = {:connect_timeout => 10}
    param_hosts = opts.delete(:hosts) if Array === opts[:hosts]

    if param_hosts
      hosts = param_hosts
    elsif pile_of_opts[:host] || pile_of_opts[:hosts]
      if pile_of_opts[:host]
        hosts = [{host: pile_of_opts.delete(:host)}]
      elsif pile_of_opts[:hosts]
        hosts = pile_of_opts.delete(:hosts).split(",").map(&:strip).map {|h|
          {host: h}
        }
      end
      if pile_of_opts[:port]
        hosts.each { |h|
          h[:port] = pile_of_opts[:port]
          h[:port] = Integer(h[:port]) if String === h[:port]
        }
      end

      if service_hosts
        hosts.map! { |h| service_hosts.first.merge h }
      end
    elsif service_hosts
      hosts = service_hosts
    else
      raise "hosts not specified"
    end
    pile_of_opts.delete(:hosts)
    pile_of_opts.delete(:host)
    raise "bad hosts specification: #{hosts.inspect}" unless Array === hosts
    hosts.each { |h|
      raise "bad host specification: #{h.inspect}" unless Hash === h
    }

    common_host_opts = service_opts.delete(:common_host_opts)&.dup || {}
    HOST_OPTS.each do |opt|
      if pile_of_opts.has_key?(opt)
        common_host_opts[opt] = pile_of_opts.delete(opt)
      end
    end
    if LOGIN_OPTS.none? { |optlist| optlist.all? { |key|
        common_host_opts[key] || hosts.all? { |host| host[key] } } }
      common_host_opts.merge! get_credentials
    end

    final_opts = default_opts.merge(service_opts).merge(pile_of_opts)
    final_opts[:hosts] = hosts.map { |h| h.merge common_host_opts }

    ## SSL options
    final_opts[:hosts].each { |host|
      host[:ssl] = to_bool(host[:ssl]) if String === host[:ssl]
      case host[:ssl]
      when false
        SSL_OPTS.each { |k| host.delete(k) }
        next
      when true, nil
        host[:ssl] = {}
      else
        raise "unknown SSL option: #{host[:ssl].inspect}"
      end

      if host[:cert_file]
        host[:ssl][:cert_file] = expand_private_path(host.delete(:cert_file))
      end
      if host[:key_file]
        host[:ssl][:key_file] = expand_private_path(host.delete(:key_file))
      end
      if host[:key_password]
        host[:ssl][:key_password] = host.delete(:key_password)
      end
      if host[:ts_files]
        ts_files = expand_path(host.delete(:ts_files))
        if File.directory?(ts_files)
          host[:ssl][:ts_files] = Dir.glob("#{ts_files}/*.{pem,crt}").join(",")
        else
          host[:ssl][:ts_files] = ts_files
        end
      end
      host[:ssl] = Stomp::SSLParams.new(host[:ssl])
    }

    @default_queue = final_opts.delete(:default_queue).gsub("_UUID_") { |m|
      SecureRandom.uuid
    }

    # check if we have all the required options
    self.class.check_opts(final_opts)
    @opts = final_opts
  end

  def new_client
    Stomp::Client.new(opts)
  end

  def self.msg_to_str(msg)
    %{
    ------------------------------
    Headers:
#{JSON.pretty_generate msg.headers}
    Body:
#{msg.body}
    ------------------------------
    }
  end

  # method checks if all required options are in place
  def self.check_opts(opts)
    opts[:hosts].each do |host|
      miss_host_opts = REQUIRED_HOST_OPTS - host.keys

      unless miss_host_opts.empty?
        raise "Your configuration is missing following host options: " \
          "#{miss_host_opts.join(", ")} Run the script with --help argument " \
          "for help"
      end
    end
  end

  private def get_credentials()
    opts = {}
    Timeout::timeout(120) {
      STDERR.puts "STOMP username (timeout in 2 minutes): "
      opts[:login] = STDIN.gets.chomp
    }
    STDERR.puts "STOMP Password: "
    opts[:passcode] = STDIN.noecho(&:gets).chomp

    return opts
  end

  # loads all the ENV variables if they exist
  def self.load_env_vars
    env_opts = {}
    env_prefix = "STOMP_BUS_"
    ENV.each do |var, value|
      if var.start_with?(env_prefix) && !value.strip.empty?
        env_opt = var[env_prefix.length..-1].downcase.to_sym
        env_opts[env_opt] = value == "false" ? false : value
      end
    end

    if env_opts[:credentials]
      env_opts[:login], env_opts[:passcode] =
        env_opts.delete(:credentials).split(":", 2)
    end

    return env_opts
  end
end
