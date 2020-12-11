require 'text-table'
require 'thread'

module BushSlicer

  # base class to display a summary of the current running instances.
  # Currently display ['name', 'uptime', 'flexy_job_id', 'region'] in a
  # tabulized format

  class InstanceSummary
    attr_accessor :jenkins

    def initialize(jenkins)
      @jenkins = jenkins
    end

    ## print out summary in a text table format
    def print_summary(summary)
      table = Text::Table.new
      table.head = ['name', 'uptime', 'flexy_job_id', 'region']
      summary.each do | s |
        row = [s[:name], s[:uptime], s[:flexy_job_id], s[:region]]
        table.rows << row
      end
      puts table
      print "There are #{summary.count} running instances in #{summary.first[:region]}\n"
    end

    # print a table of summary of all of the instances grouped by region
    def print_grand_summary(summary)
      table = Text::Table.new
      table.head = ['platform', 'region', 'total instances']
      total = 0
      summary.each do |s|
        total += s[:inst_count]
        table.rows << [s[:platform], s[:region], s[:inst_count]]
      end
      table.foot = ["Total instances", "", total]
      puts table
    end
  end

  class AwsSummary < InstanceSummary
    attr_accessor :amz
    def initialize(jenkins: nil)
      @amz = Amz_EC2.new
      @jenkins = jenkins
      @table = Text::Table.new
    end

    # @return <Hashed Array of Instances> with each hash key being keyed on the `owned` tag.
    def regroup_instances(instances)
      cluster_map = {}
      instances.each do |r|
        owned =   r.tags.select {|t| t['value'] == "owned" }
        if owned.count > 0
          rindex = owned.first['key'].split('kubernetes.io/cluster/')[-1]
        else
          rindex = "no_owner"
        end
        if cluster_map[rindex]
          cluster_map[rindex] << r
        else
          cluster_map[rindex] = [r]
        end
      end
      return cluster_map
    end

    # @instances <Array of unordered Instance obj>
    def summarize_instances(region, instances)
      summary = []
      amz = @amz
      jenkins = @jenkins
      cm = regroup_instances(instances)
      cm.each do | owned, inst_list |
        inst_list.each do | inst |
          inst_summary = {}
          # inst_summary[:inst_obj] = inst
          inst_summary[:region] = region
          inst_summary[:name]= amz.instance_name inst
          inst_summary[:uptime]= amz.instance_uptime inst
          inst_summary[:owned] = amz.instance_owned inst
          if inst_summary[:owned]
            inst_summary[:flexy_job_id] = jenkins.get_jenkins_flexy_job_id(inst_summary[:owned][0..-7])
          else
            inst_summary[:flexy_job_id] = nil
          end
          summary << inst_summary
        end
      end
      return summary
    end

    def get_summary(target_region: nil)
      regions = amz.get_regions
      region_names =  regions.map {|r| r.region_name }
      aws_instances = {}
      threads = []
      regions.each do | region |
        if target_region
          # first check name is valid
          raise "Unsupported region '#{target_region}'" unless region_names.include? target_region
          region.region_name = target_region
        end
        threads << Thread.new(Amz_EC2.new(region: region.region_name)) do |aws|
          instances = aws.get_instances_by_status('running')
          aws_instances[region.region_name] = instances
          break if target_region == region.region_name
        end
      end
      threads.each(&:join)
      grand_summary = []
      aws_instances.each do |region, inst_list|
        # print "Getting summary for region '#{region}'\n"
        summary = summarize_instances(region, inst_list)
        print_summary(summary) if inst_list.count > 0
        grand_summary << {platform: 'aws', region: region, inst_count: inst_list.count}
      end
      print_grand_summary(grand_summary)
    end

  end

  class GceSummary < InstanceSummary
    attr_accessor :gce

    def initialize(jenkins: nil)
      @gce = GCE.new
      @jenkins = jenkins
    end

    # for GCE, group the instance by network
    def regroup_instances(instances)
      cluster_map = {}

      instances.each do |inst|
        rindex = inst.network_interfaces.first.network.split('/').last
        if cluster_map[rindex]
          cluster_map[rindex] << inst
        else
          cluster_map[rindex] = [inst]
        end
      end
      return cluster_map
    end

    # @return <Array of Hash of summary>
    def summarize_instances(region, instance_list)
      summary = []
      gce = @gce
      project = gce.config[:project]
      jenkins = @jenkins
      cm = regroup_instances(instance_list)
      cm.each do | network, inst_list |
        inst_list.each do | inst |
          inst_summary = {}
          # inst_summary[:inst_obj] = inst
          inst_summary[:region] = region
          inst_summary[:name]= inst.name
          inst_summary[:uptime]= gce.instance_uptime inst
          inst_summary[:owned] = network
          if inst_summary[:owned]
            inst_summary[:flexy_job_id] = jenkins.get_jenkins_flexy_job_id(inst_summary[:owned][0..-9])
          else
            inst_summary[:flexy_job_id] = nil
          end
          summary << inst_summary
        end
      end
      return summary
    end

    def get_summary(target_region: nil)
      regions = gce.regions
      gce_instances = {}
      grand_summary = []
      targets = {}
      threads_zones = []

      if target_region
        targets[target_region] = regions[target_region]
      else
        targets = regions
      end

      targets.each do | region, zones |
        gce_instances[region] = []
        zone_threads = zones.each do |zone|
          threads_zones << Thread.new(zone) do |z|
            instances = gce.get_instances_by_status(zone: z, status: 'running')
            if instances
              instances.each do |inst|
                gce_instances[region] << inst
              end
            end
          end
        end
      end
      threads_zones.each(&:join)

      targets.each do |region, zones|
        # print "Getting summary for region #{region}\n"
        if gce_instances.keys.include? region
          summary = summarize_instances(region, gce_instances[region])
          print_summary(summary) if summary.count > 0
          grand_summary << {platform: 'gce', region: region, inst_count: summary.count}
        end
      end
      print_grand_summary(grand_summary)
    end
  end

  class AzureSummary < InstanceSummary
    attr_accessor :azure

    def initialize(jenkins: nil)
      @azure = Azure.new
      @jenkins = jenkins
    end

    def summarize_instances(cm)
      summary = []
      cm.each do |rg_name, instances|
        instances.each do |inst|
          inst_summary = {}
          inst_summary[:region] = inst[:inst].location
          inst_summary[:name]= inst[:inst].name
          inst_summary[:uptime]= inst[:uptime]
          inst_summary[:owned] = rg_name.downcase
          if inst_summary[:owned]
            inst_summary[:flexy_job_id] = jenkins.get_jenkins_flexy_job_id(inst_summary[:owned][0..-10])
          else
            inst_summary[:flexy_job_id] = nil
          end
          summary << inst_summary
        end
      end
      return summary
    end

    def get_summary
      grand_summary = []
      # default status is 'PowerState/Running'
      # cluster_map keyed off by resource_group_name
      cm = azure.get_running_instances
      summary = summarize_instances(cm)
      print_summary(summary) if summary.count > 0
      grand_summary << {platform: 'azure', region: summary.first[:region], inst_count: summary.count}
      print_grand_summary(grand_summary)
    end
  end


  class OpenstackSummary < InstanceSummary
    attr_accessor :os

    def initialize(jenkins: nil)
      @os = OpenStack.new
      @jenkins = jenkins
    end

    # instances is <Array> of server objects
    def summarize_instances(instances)
      summary = []
      sorted_instances = instances.sort_by {|k, v| k}.to_h
      sorted_instances.each do |name, inst|
        inst_summary = {}
        inst_summary[:region] = 'upshift'
        inst_summary[:name]= name
        inst_summary[:uptime]= os.instance_uptime inst["created"]
        inst_summary[:owned] =  name
        inst_summary[:flexy_job_id] = jenkins.get_jenkins_flexy_job_id(name[0..13])
        summary << inst_summary
      end
      return summary
    end

    def get_summary
      grand_summary = []
      inst_details = os.get_running_instances
      # sleep 15
      summary = summarize_instances(inst_details)
        # summary = summarize_instances(rg_name, instances)
      print_summary(summary) if summary.count > 0
      grand_summary << {platform: 'openstack', region: summary.first[:region], inst_count: summary.count}
      print_grand_summary(grand_summary)
    end
  end

  class PacketSummary < InstanceSummary
    attr_accessor :packet

    def initialize(jenkins: nil)
      @packet = Packet.new
      @jenkins = jenkins
    end

    # instances is <Array> of server objects
    def summarize_instances(instances)
      summary = []
      instances.each do | inst |
        inst_summary = {}
        inst_summary[:region] = 'packet'
        inst_summary[:name]= inst['hostname']
        inst_summary[:uptime]= packet.instance_uptime inst["created_at"]
        inst_summary[:owned] = inst['created_by']['email']
        inst_summary[:flexy_job_id] = jenkins.get_jenkins_flexy_job_id(inst['hostname'])
        summary << inst_summary
      end
      return summary
    end

    def get_summary
      grand_summary = []
      inst_details = packet.get_running_instances
      summary = summarize_instances(inst_details)
      # summary = summarize_instances(rg_name, instances)
      print_summary(summary) if summary.count > 0
      grand_summary << {platform: 'openstack', region: summary.first[:region], inst_count: summary.count}
      print_grand_summary(grand_summary)
    end
  end


  class VSphereSummary < InstanceSummary
    attr_accessor :vms

    def initialize(profile_name="vsphere_vmc7-qe", jenkins: nil)
      @vms = BushSlicer::VSphere.new(service_name: profile_name)
      @jenkins = jenkins
    end

    # instances is <Array> of server objects
    def summarize_instances(instances)
      summary = []
      instances.each do | inst |
        inst_summary = {}
        inst_summary[:region] = 'vSphere'
        inst_summary[:name]= inst['name']
        inst_summary[:uptime]= vms.instance_uptime(inst.config.createDate)
        inst_summary[:flexy_job_id] = jenkins.get_jenkins_flexy_job_id(inst['name'])
        summary << inst_summary
      end
      return summary
    end

    def get_summary
      grand_summary = []
      inst_details = vms.get_running_instances
      summary = summarize_instances(inst_details)
      # summary = summarize_instances(rg_name, instances)
      print_summary(summary) if summary.count > 0
      grand_summary << {platform: 'vSphere', region: summary.first[:region], inst_count: summary.count}
      print_grand_summary(grand_summary)
    end
  end
end

