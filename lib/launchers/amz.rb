#!/usr/bin/env ruby
require 'aws-sdk'

require 'common'
require 'host'
require 'launchers/cloud_helper'

module VerificationTests

  class Amz_EC2
    include Common::Helper
    include Common::CloudHelper

    attr_reader :config

    def initialize(access_key: nil, secret_key: nil, service_name: nil)
      service_name ||= :AWS
      @config = conf[:services, service_name]
      @can_terminate = true

      if access_key && secret_key
        awscred = {
          "AWSAccessKeyId" => access_key,
          "AWSSecretKey" => secret_key
        }
      else
        # try to find a suitable Amazon AWS credentials file
        [ expand_private_path(config[:awscred]),
        ].each do |cred_file|
          begin
            cred_file = File.expand_path(cred_file)
            logger.info("Using #{cred_file} credentials file.")
            awscred = Hash[File.read(cred_file).scan(/(.+?)=(.+)/)]
            break # break if no error was raised above
          rescue
            logger.warn("Problem reading credential file #{cred_file}")
            next # try next configuration file
          end
        end
      end

      raise "no readable credentials file or external credentials config found" unless awscred

      Aws.config.update( config[:config_opts].merge({
        credentials: Aws::Credentials.new(
          awscred["AWSAccessKeyId"],
          awscred["AWSSecretKey"]
        )
      }) )
      client = Aws::EC2::Client.new
      @ec2 = Aws::EC2::Resource.new(client: client)

    end

    private def client_sts
      @client_sts ||= Aws::STS::Client.new
    end

    # @param ecoded_message [String]
    # @return [String] in JSON format
    def decode_authorization_message(encoded_message)
      decoded = client_sts.decode_authorization_message(encoded_message: encoded_message)
      if decoded.successful?
        return decoded.data.decoded_message
      else
        raise decoded.error
      end
    end

    def create_instance(image_id=nil)
      launch_instances(image=image_id)
    end

    ########################################################################
    # AMI helper methods
    ########################################################################
    def get_amis(filter_val=config[:ami_types][:devenv_wildcard])
      # returns a list of amis
       @ec2.images({
        filters: [
            {
              name: "name",
              values: [filter_val],
            },
            {
              name: "state",
              values: ["available"],
            },
          ],
       }).to_a
    end

    def get_all_qe_ready_amis()
      # returns a list of amis
       @ec2.images({
        filters: [
            {
              name: "state",
              values: ["available"],
            },
            {
              name: "tag-value",
              values: [config[:tag_ready]],
            },
          ],
        })

    end
    # Returns the ami-id given a name
    # @return [Sting] ami-id, if no match then nil
    #
    def get_ami_id_from_name(ami_name)
      ami = @ec2.images({
        filters: [
            {
              name: "name",
              values: [ami_name],
            },
          ],
        }).to_a
      if ami.count == 0
        return nil
      else
        return ami[0].id
      end
    end

    def filter_available_amis(*filters)
      filters << {
        name: "state",
        values: ["available"]
      }
      return @ec2.images({ filters: filters })
    end

    def filter_qe_ready_amis(*filters)
      filters << {
        name: "tag-value",
        values: [config[:tag_ready]]
      }
      return filter_available_amis(*filters)
    end

    def get_latest_ami(filter_val = nil)
      v3_types = [:fedora, :centos7, :rhel7, :rhel7next]
      case filter_val
      when nil
        # latest devenv regardless of OS
        filter_val = v3_types.map { |t| filter_val=config[:ami_types][t] }
      when Array
        # do nothing
      when String
        filter_val = filter_val.split(",")
      else
        raise "dunno what this filter is: #{filter_val.inspect}"
      end

      amis = filter_qe_ready_amis({name: "name", values: filter_val}).to_a
      if amis.empty?
        logger.warn("no qe-ready AMIs found, trying non-ready with names: #{filter_val}")
        amis = filter_available_amis({name: "name", values: filter_val})
      end

      # take latest ami by date
      img = amis.sort_by {|ami| ami.creation_date}.last
      unless img
        raise "could not find specified image: #{filter_val}"
      end
      return img
    end

    # TODO: convert to v2 AWS API
    # Returns snaphost hash
    # @return [Hash] snapshot_set
    # example: {:tag_set=>[], :snapshot_id=>"snap-b4f04508", :volume_id=>"vol-81ab9fce", :status=>"completed", :start_time=>2014-11-11 16:05:50 UTC, :progress=>"100%", :owner_id=>"531415883065", :volume_size=>25, :description=>"Created by CreateImage(i-37f49418) for ami-1e51db76 from vol-81ab9fce", :encrypted=>false}
    # def get_snapshot_info(ami_id)
    #   client = @ec2.client
    #   res = @ec2.client.describe_images({:image_ids => [ami_id]})
    #   begin
    #     snapshot_id = res.images_set[0].block_device_mapping[0].ebs.snapshot_id
    #     snapshot_res = client.describe_snapshots({:snapshot_ids=> [snapshot_id]})
    #     return snapshot_res.snapshot_set[0]
    #   rescue
    #     $logger.info("Unable to get ami creation time for #{ami_id}, will be not stored into database")
    #     return nil
    #   end
    # end

    # Returns latest devenv_* AMI
    # @return [String] ami-id
    def get_latest_v2_ami
      return get_latest_ami(config[:ami_types][:devenv_v2])
    end

    # Returns latest devenv-stage_* AMI
    # @return [String] ami-id
    def get_latest_stable_v2_ami
      return get_latest_ami(config[:ami_types][:devenv_stable_v2])
    end

    def can_terminate?
      !!@can_terminate
    end

    # @param [String] ec2_tag the EC2 'Name' tag value
    # @return [Array<String>, Array<Object>] the array of IP address with array of instances object
    #
    def get_instance_ip_by_tag(ec2_tag)
      instances = @ec2.instances({
        filters: [
          {
            name: "tag:Name",
            values:[ec2_tag],
          },
        ]
      }).to_a
      if block_given?
        instances.each do |i|
          yield(i)
        end
      else
        ips = instances.map { |i| i.public_dns_name }
        return ips, instances
      end
    end

    #
    # @return [Array<Object>]
    def get_instance_by_id(ec2_instance_id)
      return @ec2.instances({
        filters: [
          {
            name: "instance-id",
            values:[ec2_instance_id],
          },
        ]
      }).to_a[0]
    end

    def get_instance_by_ip(ec2_instance_ip)
      # convert dns name to IP if necessary
      require 'resolv'
      ec2_instance_ip = Resolv.getaddress(ec2_instance_ip) unless ec2_instance_ip =~ /^[0-9]/
      res = @ec2.instances({
        filters: [
          {
            name: "ip-address",
            values:[ec2_instance_ip],
          },
        ]
      }).to_a[0]
    end

    # @return [Array<Instance>]
    def get_instances_by_name(*instance_names)
      res = @ec2.instances({
        filters: [
          {
            name: "tag:Name",
            values: instance_names
          }
        ]
      }).to_a
    end

    # @param [String] ami_id the EC2 AMI-ID
    # @return [Array<String>, Array<Object>] the array of IP address with array of instances object
    def get_instance_ip_by_ami_id(ami_id)
      instances = @ec2.instances({
        filters: [
          {
            name: "image-id",
            values:[ami_id],
          },
        ]
      }).to_a
      ips = instances.map{ |i| i.public_dns_name }
      return ips, instances
    end

    def add_name_tag(instance, name, retries=2)
      retries.times do |i|
        begin
          # tag the instance
          return instance.create_tags({
            tags: [
              {
                key: "Name",
                value: name,
              },
            ]
            })
        rescue Exception => e
          logger.info("Failed adding tag: #{e.inspect}")
          if i >= retries - 1
            raise "could not add name tag after #{retries} attempts"
          end
          sleep 5
        end
      end
      raise "should never be here"
    end

    def instance_status(instance)
      10.times do |i|
        begin
          status = instance.state[:name].to_sym
          return status
        rescue Exception => e
          if i >= 10 - 1
            raise "Failed to get instance status after 10 retries: #{e.inspect}"
          end
          logger.info("Error getting status(retrying): #{e.inspect}")
          sleep 30
        end
      end
      raise "should never be here"
    end

    def get_volume_by_openshift_metadata(pv_name, project_name)

      return @ec2.volumes({dry_run: false, filters: [{name: "tag:kubernetes.io/created-for/pv/name", values: [pv_name]},{name: "tag:kubernetes.io/created-for/pvc/namespace", values: [project_name]}]}).first
    end

    def get_volume_by_id(id)
      # format the id provided by openshift into a format amazon REST api can work with
      id = id.split("/")[-1]
      begin
        vol = @ec2.volume(id)
        # the @ec2 will always return a volume object. It will raise an error only when
        # a method is invoked on the object. Thats why we use if vol.state to check
        # if the volume exists
        return vol if vol.state
      rescue Aws::EC2::Errors::InvalidVolumeNotFound
        return nil
      end
    end

    def get_volume_state(volume)
        return volume.state
    end


    # returns ssh connection
    def get_host(instance, host_opts={}, wait: false)
      host_opts = config[:host_opts].merge host_opts
      host_opts[:cloud_instance] = instance
      host_opts[:cloud_instance_name] = instance.tags.find{|t| t[:key] == "Name"}[:value]
      if instance.public_dns_name == ''
        logger.info("Reloading instance...")
        instance.reload
      end

      hostname = instance.public_dns_name
      host = VerificationTests.const_get(config[:hosts_type]).new(hostname, host_opts)
      if wait
        logger.info("Waiting for #{hostname} to become accessible..")
        begin
          host.wait_to_become_accessible(600)
        rescue
          terminate_instance(instance)
          raise
        end
        logger.info "Instance (#{hostname}) is accessible"
      else
        logger.info("hostname: #{hostname}")
      end
      return host
    end

    # @return [String]
    def access_key
      @ec2.client.config.credentials.access_key_id
    end

    # @return [String]
    def secret_key
      @ec2.client.config.credentials.secret_access_key
    end

    # @return [Object] undefined
    def terminate_instance(instance)
      # we don't really have root permission to terminate, we'll just label it
      # 'teminate-qe' and let charlie takes care of it.
      name = instance.tags.find{|t| t.key == "Name"}&.value || "qe"
      logger.info("Terminating instance #{name} #{instance.public_dns_name}")

      terminated = false
      if can_terminate?
        begin
          terminated = !! instance.terminate
        rescue Aws::EC2::Errors::UnauthorizedOperation => e
          @can_terminate = false
        end
      end

      unless terminated
        logger.warn("not permitted to terminate, stopping and renaming to terminate-#{name}")
        instance.stop({force: true})
        add_name_tag(instance, "terminate-#{name}")
      end
    end

    # @param [Array<Hash>] launch_opts where each element is in the format
    #   `{name: "some-name", launch_opts: {...}}`
    # @return [Object] undefined
    def terminate_by_launch_opts(launch_opts)
      names = launch_opts.map {|o| o[:name]}.sort

      if names.any? { |n| !n.kind_of?(String) || n.empty? }
        raise "all instance names must be non-empty strings: #{names}"
      end

      if names != names.uniq
        raise "instances to delete must have unique names: #{names.join(" ,")}"
      end

      instances = get_instances_by_name(*names)
      found_names = instances.
        map {|i| i.tags.find{|t| t.key == "Name"}&.value}.
        sort

      if found_names != found_names.uniq
        raise "found instances should have unique names: #{found_names}"
      end

      unless (found_names - names).empty?
        raise "filtered for #{names} but found: #{found_names}"
      end

      instances.each { |i| terminate_instance(i) }
    end

    # Launch an EC2 instance either based on particular AMI or with the latest one.
    # If a tag_name is given then launch instance with it, otherwise use
    # the naming convention of QE_devenv_<latest_ami>
    #
    # @param [String] image the AMI id or filter type (e.g. rhel7, stage, etc.)
    # @param [Array, String] tag_name the tag name(s) for EC2 instance(s);
    #   is Array, it overrides min/max count with the number of elements
    # @param [Hash] create_opts for EC2, see
    #   http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Resource.html#create_instances-instance_method
    # @param [Integer] max_retries max retries to try (TODO)
    #
    # @return [Array] of [amz_instance, VerificationTests::Host] pairs
    #
    def launch_instances(image: nil,
                         tag_name: nil,
                         create_opts: nil,
                         host_opts: {},
                         max_retries: 1,
                         wait_accessible: false)
      # default to use rhel if no filter is specified
      instance_opt = config[:create_opts] ? config[:create_opts].dup : {}
      instance_opt.merge!(create_opts) if create_opts
      tags = instance_opt.delete(:tags) || {}

      if image.kind_of? Symbol
        image = config[:ami_types][image]
      end

      case image
      when Aws::EC2::Image
        instance_opt[:image_id] = image.id
      when nil
        unless instance_opt[:image_id]
          image = get_latest_ami
          instance_opt[:image_id] = image.id
        end
      when /^ami-.+/
        instance_opt[:image_id] = image
        # image = @ec2.images[image]
      else
        logger.info("Using image filter #{image}...")
        image = self.get_latest_ami(image)
        instance_opt[:image_id] = image.id
      end

      case tag_name
      when nil
        unless image.kind_of? Aws::EC2::Image
          image = @ec2.images[instance_opt[:image_id]]
        end
        tag_name = [ "QE_" + image.name + "_" + rand_str(4) ]
      when String
        tag_name = [ tag_name ]
      when Array
        instance_opt[:min_count] = instance_opt[:max_count] = tag_name.size
      end

      logger.info("Launching EC2 instance from #{image.kind_of?(Aws::EC2::Image) ? image.name : image.inspect} named #{tag_name}...")
      instances = @ec2.create_instances(instance_opt)

      res = []
      instances.each_with_index do | instance, i |
        inst_tags = tags.each_with_object([]) { |(key,value),memo|
          case key
          when "Name", :Name, "name", :name
          else
            memo << {key: key.to_s, value: value}
          end
        }
        inst_tags << {key: "Name", value: tag_name[i] || tag_name.last}
        begin
          inst = instance.wait_until_running
        rescue Aws::Waiters::Errors::FailureStateError => e
          r = e.response
          logger.error r.data
          if r.error
            logger.error e
            raise r.error
          else
            raise e
          end
        rescue Aws::Waiters::Errors::UnexpectedError => e
          logger.error e
          raise e.error
        end
        logger.info("Tagging instance with #{inst_tags} ..")
        inst.create_tags({ tags: inst_tags })
        inst.tags.concat inst_tags # odd that we need this
        # make sure we can ssh into the instance
        host = get_host(inst, host_opts, wait: wait_accessible)
        res << [inst, host]
      end
      return res
    end
  end
end
