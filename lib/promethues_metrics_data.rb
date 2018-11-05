module BushSlicer
  class PrometheusMetricsData

    def initialize(metrics)
      @metrics = metrics
    end

    def get_one(name: , labels: nil, key: "value")
      res = JSON.load(@metrics).find{|item| item["name"] == name}
      return res if !res
      return res["metrics"][0][key] if !labels

      labels = labels.split(",").map{|l| l.split(":", 2)}.to_h
      metrics_item = res["metrics"].find {|item| item.has_key?("labels") && Collections.substruct?(labels, item["labels"])}
      return metrics_item&.fetch(key, nil)
    end
  end
end
