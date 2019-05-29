module BushSlicer
  class ReportDataSource < ProjectResource
    RESOURCE = "reportdatasources"

    def last_import_time(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'prometheusMetricsImportStatus', 'lastImportTime')
    end

    def newest_imported_metric_time(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'prometheusMetricsImportStatus', 'newestImportedMetricTime')
    end

    def earliest_imported_metric_time(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'prometheusMetricsImportStatus', 'earliestImportedMetricTime')
    end

    def table_name(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('status', 'tableRef', 'name')
    end

    def prometheus_metrics_importer_query(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'prometheusMetricsImporter', 'query')
    end

  end
end
