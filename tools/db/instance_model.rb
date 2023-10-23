# lib to describe a mongodb database's model in class format
#
#
require 'date'
require 'mongoid'
require 'text-table'
require 'pry-byebug'

class Instance
   include Mongoid::Document
   include Mongoid::Attributes::Dynamic
end


def print_summary(summary)
  table = Text::Table.new
  table.head = ['infra_id', 'duration', 'region', 'type', 'cost']
  summary.each do |s|
    begin
      duration = sprintf("%.2f", s['duration'])
    rescue
      duration = nil
    end
    cost = s['inst_cost']
    cost = 0.0 if cost.nil?
    cost = sprintf("%.2f", cost)
    row = [s['inst_id'], s['duration'], s['region'], s['type'], cost]
    table.rows << row
  end
  print table
end

module BushSlicer
  class ClusterInstance
    attr_accessor :db, :opts
    def initialize
      @db = Mongoid.load!('db/mongoid.yaml', :development)
    end

    def details(opts:)
      @opts = opts
      start_date = Date.strptime(opts.start_date)
      end_date = Date.strptime(opts.end_date)
      (start_date..end_date).each do |date|
        summarize_cluster_usage_by_date(date: date)
        # Do stuff with date
      end
      # total_run = Instance.where().to_a.count
    end
    # given a list of infra_ids
    # separate ci clusters vs normal user clusters
    def profile_cluster_breakdown(results)
      ci_cluster_prefix = ['qeci-', 'cam-', 'logci', 'qe-daily-']

      buckets = {'ci': [], 'normal': []}
      results.each do | inst |
        res = ci_cluster_prefix.select {|i| inst.start_with? i}
        if res.count > 0
          buckets[:ci] << inst
        else
          buckets[:normal] << inst
        end
      end
      print "Cluster total: #{results.count}, #{buckets[:ci].count} 'ci-clusters', #{buckets[:normal].count} 'normal-clusters'\n"
      return buckets
    end

    # given a list of instances results, calculate the cost
    def calculate_cost(instances)
      amz_prices = {
        "i3.large" => 0.15,
        "m5.xlarge" => 0.192,
        "m5.2xlarge" => 0.384,
        "m5.4xlarge" => 0.768,
        "m5.8xlarge" => 1.536,
        "m5.large" => 0.096,
        "m5a.large" => 0.086,
        "m6g.xlarge" => 0.154,
        "m6g.large" => 0.077,
        "m5a.xlarge"   =>0.172,
        "m5a.2xlarge" => 0.344,
        "m5a.4xlarge" => 0.688,
        "m5a.8xlarge" => 1.376,
        "m4.2xlarge" => 0.40,
        "m4.xlarge"  => 0.20,
        "m4.large" => 0.10,
        "r5.xlarge" => 0.252,
        "t2.medium" => 0.0464,
        "t2.micro" => 0.0116,
        "t3a.micro" => 0.0094,
        "c4.4xlarge" => 0.796,
        "c4.2xlarge" => 0.398,
        "c4.xlarge" => 0.199,
        "c5.xlarge" => 0.17,
        "c5.2xlarge" => 0.34,
        "c5.4xlarge" => 0.68,
        "c5.9xlarge" => 1.53,
        "r4.large" => 0.133,
        "r4.xlarge" => 0.266,
        "r4.2xlarge" => 0.532,
        "r5a.xlarge" => 0.226,
        "t3a.xlarge" => 0.1504,
        "c5a.24xlarge" => 3.696,
        "t3.xlarge" => 0.1664,
        "m5.16xlarge" => 3.072,
        "m5a.16xlarge" => 2.752,
        "m5a.12xlarge" => 2.064,
        "c5a.12xlarge" => 1.848,
        "c5a.2xlarge" => 0.308,
        "m4.16xlarge" => 3.20,
        "m4.10xlarge" => 2.00,
        "m4.4xlarge" => 0.80,
        "c5a.8xlarge" => 1.232,
        "c5a.4xlarge" => 0.616,
        "c5.18xlarge" => 3.06,
        "c5.12xlarge" => 2.04,
        "c5.24xlarge" => 4.08,
        "t3.large" => 0.0832,
      }
      data = []
      total_cost =0.0
      instances.each do |inst|
        summary = {}
        if inst.inst_remove_time
          summary['duration'] = inst.inst_remove_time - inst.inst_launch_time
        else
          summary['duration'] = 0
        end
        summary['inst_id'] = inst.inst_infra_id
        summary['type'] = inst.inst_type
        summary['region'] = inst.inst_region
        begin
          summary['inst_cost'] = (summary['duration']/Float(60 * 60)) * amz_prices[inst.inst_type]
        rescue
          binding.pry
        end
        total_cost += summary['inst_cost']
        data << summary
      end
      print_summary(data) if @opts.verbose
      printf("Total cost: $%.2f\n", total_cost)
      return total_cost
    end

    def region_breakdown(instances)
      regions  = instances.map {|i| i.inst_region }
      types = instances.map {|i| i.inst_type }
      print("regions: #{regions.group_by(&:itself).transform_values(&:count)}\n")
      print("types: #{types.group_by(&:itself).transform_values(&:count)}\n")
    end

    def cluster_uptime_breakdown(instances)
      inst_cnt = 0
      uptime_hash = {}
      instances.each do |inst|
        if inst.inst_remove_time.nil?
          next
        else
          uptime_hash[inst.inst_infra_id] ||= []
          uptime_hash[inst.inst_infra_id] << (inst.inst_remove_time - inst.inst_launch_time)/(60 * 60)
        end
      end
      # go through Hash again to do the average
      cluster_uptime_avg = []
      cluster_uptime_avg_hash = {}

      uptime_hash.each do |k, v|
        cluster_uptime = v.sum/v.count
        cluster_uptime_avg_hash[k] = cluster_uptime
        cluster_uptime_avg << cluster_uptime
      end
      average_cluster_time = cluster_uptime_avg.sum / cluster_uptime_avg.count
      max_cluster_time = cluster_uptime_avg.max
      min_cluster_time = cluster_uptime_avg.min
      printf("Max cluster uptime: %.2f\n", max_cluster_time)
      printf("Min cluster uptime: %.2f\n", min_cluster_time)
      printf("Average cluster uptime: %.2f\n", average_cluster_time)
    end
    # # give a summary based on each day
    #
    # 1.  number of instances/cluster each day
    # 2. type of instance
    # 3. total cost per day.
    # 4. instance region distribution
    # 5. average uptime of instances/clusters
    # 6. average uptime of instances/clusters
    # 7. max/min uptime of instances
    def summarize_cluster_usage_by_date(date: )
      print("*" * 70 + "\n")
      print("Summary for date #{date.to_s}\n")
      instances = Instance.where(inst_launch_time: (date..date+1)).to_a
      print("Total instances: #{instances.count}\n")
      infra_ids = instances.map {|i| i.inst_infra_id }.uniq.sort
      # separate ci vs normal cluster
      cluster_profiles = profile_cluster_breakdown(infra_ids)
      total_day_cost = calculate_cost(instances)
      region_breakdown(instances)
      cluster_uptime_breakdown(instances)
    end

  end
end

if __FILE__ == $0
  ci = BushSlicer::ClusterInstance.new
end
