require 'text-table'
module BushSlicer
  # represents what we want to show in the summary output
  # 1. platform   (aws, azure, gce, openstack, and etc)
  # 2. instance_name
  # 3. uptime
  # 4. link to Flexy job ID that was used to spin it up (none if nont-Fles
  #
  class InstanceSummary
    attr_accessor :jenkins

    def initialize(jenkins: nil)
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
      table.rows << ["Total instances:", "", total]
      puts table

    end

  end

  class AwsSummary < InstanceSummary
    attr_accessor :amz, :summary, :table
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
      regions.each do | region |
        ### for init debugging use one region only
        if target_region
          # first check name is valid
          raise "Unsupported region '#{target_region}'" unless region_names.include? target_region
          amz = Amz_EC2.new(region: target_region)
          instances = amz.get_instances_by_status('running')
          aws_instances[target_region] = instances
          break
        else
          amz = Amz_EC2.new(region: region.region_name)
          inst = amz.get_instances_by_status('running')
          aws_instances[region.region_name] = inst
        end

      end
      grand_summary = []
      aws_instances.each do |region, inst_list|
        print "Getting summary for region '#{region}'\n"
        summary = summarize_instances(region, inst_list)
        print_summary(summary) if inst_list.count > 0
        grand_summary << {platform: 'aws', region: region, inst_count: inst_list.count}
      end
      print_grand_summary(grand_summary)
    end

  end

  class GceSummary < InstanceSummary
    # WIP:
  end

  class AzureSummary < InstanceSummary
    # WIP:
  end

end
