module BushSlicer
  class ReportDataSource < ProjectResource
    RESOURCE = "reportdatasources"

    def last_import_time(user: nil, cached: false, quiet: false)
      raw_resource.dig('status', 'prometheusMetricImportStatus', 'lastImportTime')
    end

    def newest_imported_metric_time(user: nil, cached: false, quiet: false)
      raw_resource.dig('status', 'prometheusMetricImportStatus', 'newestImportedMetricTime')
    end

    def earliest_imported_metric_time(user: nil, cached: false, quiet: false)
      raw_resource.dig('status', 'prometheusMetricImportStatus', 'earliestImportedMetricTime')
    end

    def table_name(user: nil, cached: false, quiet: false)
      raw_resource.dig('status', 'tableName')
    end
  end
end
