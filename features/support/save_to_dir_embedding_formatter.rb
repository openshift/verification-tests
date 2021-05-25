require 'base64'
require 'fileutils'
require 'tmpdir' # Dir.tmpdir

module BushSlicer
  class SaveToDirEmbeddingFormatter
    attr_reader :target_dir
    private :target_dir

    def initialize(config)
      path = config.out_stream

      if ENV['WORKSPACE'] && File.directory?(ENV['WORKSPACE'])
        # in jenkins it would be nice to have formatter log in WORKSPACE
        basedir = ENV['WORKSPACE']
      else
        basedir = Dir.tmpdir
      end

      case path
      when %r{^[^-_a-zA-Z0-9]+$}
        raise "target dir should not be an empty or only special characters"
      when %r{^/}
        @target_dir = path
      else
        @target_dir = File.join(basedir, path)
      end

      FileUtils.mkdir_p(@target_dir)
      unless File.directory? @target_dir
        raise "could not create file embedder target directory"
      end
    end

    # @note #embed has been replaced by #attach in Cucumber 5.x
    def attach(src, media_type)
      if media_type == 'image/png;base64'
        embed(src, media_type, "#{$screenshot_label}")
      elsif media_type != 'text/x.cucumber.log+plain'
        embed(src, media_type, "test case execution attachment")
      end
    end

    # @see CucuFormatter
    def embed(src, mime_type, label)
      if (File.file?(src) rescue false)
        FileUtils.cp src target_dir
        return
      elsif src =~ /\Adata:[-a-zA-Z0-9_]+\/[-a-zA-Z0-9_+.;=]+;base64,([A-Za-z0-9+\/]+=*)\z/
        ## random type Data URI
        content = Base64.decode64(Regexp::last_match[1])
      elsif mime_type =~ /\A[-a-zA-Z0-9_]+\/[-a-zA-Z0-9_+.;=]+;base64\z/ &&
        src =~ /\A[A-Za-z0-9+\/]+=*\z/
        ## Base64 encoded raw data
        content = Base64.decode64(src)
      else
        ## random raw data
        content = src
      end

      File.write(File.join(target_dir, label), content, mode: "wb")
    end
  end
end
