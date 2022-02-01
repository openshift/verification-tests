lib_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end

require 'collections'
require 'common'

module BushSlicer
  class Rdu_IPI_BM
    include Common::Helper
    include CollectionsIncl
    attr_reader :config

    def initialize(**opts)
      @config = conf[:services, opts.delete(:service_name) || :rdu_ipi_bm]
    end
  end
end
