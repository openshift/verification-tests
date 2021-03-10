module BushSlicer
  # represents a discovered storage device for local storage operator
  # {"deviceID"=>"/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol0aae98a99ce01086e",
  #   "fstype"=>"",
  #   "model"=>"Amazon Elastic Block Store              ",
  #   "path"=>"/dev/nvme1n1",
  #   "property"=>"NonRotational",
  #   "serial"=>"vol0aae98a99ce01086e",
  #   "size"=>2147483648,
  #   "status"=>{"state"=>"Available"},
  #   "type"=>"disk",
  #   "vendor"=>""
  # }
  class DiscoveredDevices
    include Common::Helper

    attr_reader :struct
    private :struct

    def initialize(struct)
      @struct = struct
    end

    def device_id
      struct['deviceID']
    end

    def fstype
      struct['fstype']
    end

    def model
      struct['model']
    end

    def path
      struct['path']
    end

    def property
      struct['property']
    end

    def serial
      struct['serial']
    end

    def size
      struct['size']
    end

    def status
      struct['status']['state']
    end

    def type
      struct['type']
    end

    def vendor
      struct['vendor']
    end
  end
end
