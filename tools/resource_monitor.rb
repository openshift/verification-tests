require 'text-table'
require 'thread'
require 'openshift_qe_slack'
#require 'pry-byebug'

module BushSlicer

  # base class to display a cloud resource .

  class ResourceMonitor
    attr_accessor :slack

    def print_summary()
      print("Resoruce summary...")
    end

    # @returns a list of users' slack user_ids and list of unknown users
    def translate_to_slack_users(users: nil, slack_client:)
      # 1. get the slacker_users lookup map
      users_map_hash = slack_client.build_user_map
      # 2. separate valid users from unknown into their buckets
      users_hash = validate_users(users_map: users_map_hash.keys, users_list: users)

      slack_user_ids = users_hash[:valid].map { |u| "<@#{users_map_hash.dig(u)}>" }
      [slack_user_ids.join(" "), users_hash[:unknown].join(" ")]
    end

    # @return Boolean (true if overlimit)
    def over_limit?(resource_type: nil, resource_value:nil, resource_limit:nil, percentage: 95)
      if resource_value/resource_limit.to_f * 100 > percentage
        msg = "#{resource_type} count #{resource_value} is over #{percentage}% of limit #{resource_limit}\n"
        return msg
      else
        return nil
      end
    end


    # call Slack webhook to send text to a particular channel.
    # slack channel URL is defined in private/config/config.yaml
    ## TODO: research doing it via ruby-slack-client instead
    def send_to_slack(summary_text: text, options: nil)
      @slack ||= BushSlicer::CoreosSlack.new(channel: '#team-qe')
      @slack.post_msg(msg: summary_text, as_blocks: true)
    end
  end

  class AwsResources < ResourceMonitor
    attr_accessor :amz

    def initialize(svc_name: "AWS-CLOUD-USAGE")
      @amz = Amz_EC2.new(service_name: svc_name)
      @limits = {:s3 => 300, :vpcs => 100}
      @table = Text::Table.new
    end
    ## print out summary in a text table format
    def print_summary(data_rows, headers)
      table = Text::Table.new

      table.head = headers
      data_rows.each do |data|
        table.rows << data
      end
      puts table
    end

    def notify_limits(limits_msgs)

      limits_msgs.each do |msg|
        print(msg)
        send_to_slack(summary_text: msg)
      end
    end

    def get_vpcs(global_region: :"AWS-CLOUD-USAGE")
      regions = @amz.get_regions
      region_names =  regions.map {|r| r.region_name }
      vpcs_hash  = {}
      raw_vpcs = []
      threads = []
      ##  XXX commnet out thread implmentation for now as it's flaky when when in jenkins
      regions.each do | region |
        threads << Thread.new(Amz_EC2.new(region: region.region_name)) do |aws|
          aws = Amz_EC2.new(service_name: global_region, region: region.region_name)
          vpcs_in_region = aws.get_vpcs()
          raw_vpcs << vpcs_in_region
          if vpcs_in_region.count > 0
            vpcs_hash[region.region_name] = vpcs_in_region
          end
        end
      end
      threads.each(&:join)
      ### uncomment the following if not using thread
      # regions.each do | region |
      #   aws = Amz_EC2.new(service_name: global_region, region: region.region_name)
      #   vpcs_in_region = aws.get_vpcs()
      #   if vpcs_in_region.count > 0
      #     vpcs_hash[region.region_name] = vpcs_in_region
      #   end
      # end
      return vpcs_hash, raw_vpcs
    end

    # @return an array of ['name', 'date']
    def extract_vpcs_data(raw_vpcs)
      vpcs = raw_vpcs.flatten
      data = []
      target_data = ['openshift_creationDate', 'Name', "expirationDate"]
      vpcs.each do |vpc|
        row_data_hash = {}
        vpc.tags.each do |tag|
          if tag.key == 'Name' or tag.key == 'openshift_creationDate'
            row_data_hash[tag.key] = tag.value
          end
        end
        data << row_data_hash
      end
      s_data = data.select {|d| d.has_key? 'Name' and d.has_key? "openshift_creationDate"}
      data_list = []
      s_data.each do |data|
        data_list<< [data['Name'], data['openshift_creationDate']]
      end
      return data_list
    end

    # @instances <Array of unordered Instance obj>
    def summarize_resources(resources: ['s3, vpc'])
      vpcs_hash, raw_vpcs = self.get_vpcs
      vpcs_total = 0
      summary_data = []
      limits_msgs = []

      vpcs_limit = @limits[:vpcs]
      s3_buckets_limits = @limits[:s3]
      vpcs_hash.each do |region, vpcs|
        vpcs_total += vpcs.count
        row_data = [region, vpcs.count]
        summary_data<< row_data
        limits_msg = over_limit?(resource_type: "vpc in region #{region}",resource_value: vpcs.count, resource_limit: vpcs_limit, percentage: 80)
        limits_msgs << limits_msg unless limits_msg.nil?
      end
      vpcs_header = ['region', 'total']
      print_summary(summary_data, vpcs_header)
      vpcs_name_date_list = extract_vpcs_data(raw_vpcs)
      vpcs_name_date_header = ['name', 'creation_date']
      print_summary(vpcs_name_date_list, vpcs_name_date_header)

      s3_buckets = @amz.s3_list_buckets
      s3_limits_msg = over_limit?(resource_type: "s3 buckets", resource_value: s3_buckets.count, resource_limit: s3_buckets_limits, percentage: 90)
      limits_msgs << s3_limits_msg unless s3_limits_msg.nil?
      notify_limits(limits_msgs)
      print("VPCS total: #{vpcs_total}\n")
      print("S3 bucket total: #{s3_buckets.count}\n")

    end


  end

  class GceRources < ResourceMonitor
    attr_accessor :gce

    def initialize(jenkins: nil)
      @gce = GCE.new
    end

    # @return <Array of Hash of summary>
    def summarize_resource()
      summary = []
      gce = @gce
      project = gce.config[:project]
    end

  end

  class AzureResources < ResourceMonitor
    attr_accessor :azure

    def initialize(jenkins: nil)
      @azure = Azure.new
    end

    def summarize_resource(cm)
      print "Summaring resource ..."
    end

  end


  class OpenstackResources < ResourceMonitor
    attr_accessor :os

    def initialize()
      @os = OpenStack.new
    end

    def summarize_resources()
      return summary
    end

  end

  class PacketResources < ResourceMonitor
    attr_accessor :packet

    def initialize(jenkins: nil)
      @packet = Packet.new
    end

    # instances is <Array> of server objects
    def summarize_instances(instances)
      summary = []
    end

  end


  class VSphereResources < ResourceMonitor
    attr_accessor :vms

    def initialize(profile_name="vsphere_vmc7-qe", jenkins: nil)
      @vms = BushSlicer::VSphere.new(service_name: profile_name)
    end

    # instances is <Array> of server objects
    def summarize_resource(instances)
    end

  end

  class AliCloudResources < ResourceMonitor
    attr_accessor :ali
    def initialize(svc_name: :alicloud-v4, jenkins: nil)
      @ali = Alicloud.new(service_name: svc_name, region: 'us-east-1')
    end

    # @instances <Array of unordered Instance obj>
    def summarize_resource(region, instances)
      summary = []
      ali = @ali
    end
  end
end
