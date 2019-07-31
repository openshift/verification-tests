module BushSlicer
  class ReportQuery < ProjectResource
    RESOURCE = "reportquery"
    # return: Array of column names
    def column_names(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'columns').map {|c| c['name']}
    end

  end
end
