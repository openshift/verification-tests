require 'erb'
require 'find'
require 'openssl'
require 'zip'

require_relative 'resource/chrome_crx3/crx3.pb.rb'

class ChromeExtension
  def self.gen_rsa_key(len=2048)
    OpenSSL::PKey::RSA.generate(len)
  end

  #  @note original crx2 format description https://web.archive.org/web/20180114090616/https://developer.chrome.com/extensions/crx
  def self.header_v2_extension(data, key: nil)
    key ||= gen_rsa_key()
    digest = OpenSSL::Digest.new('sha1')
    header = String.new(encoding: "ASCII-8BIT")

    # it is exactly same signature as `ssh_do_sign(data)` from net/ssh does
    signature = key.sign(digest, data)
    signature_length = signature.length
    pubkey_length = key.public_key.to_der.length

    header << "Cr24"
    header << [ 2 ].pack("V") # version
    header << [ pubkey_length ].pack("V")
    header << [ signature_length ].pack("V")
    header << key.public_key.to_der
    header << signature

    return header
  end

  #  @note file format spec pointers:
  #    https://groups.google.com/a/chromium.org/d/msgid/chromium-extensions/977b9b99-2bb9-476b-992f-97a3e37bf20c%40chromium.org
  def self.header_v3_extension(data, key: nil)
    key ||= gen_rsa_key()

    digest = OpenSSL::Digest.new('sha256')
    signed_data = Crx_file::SignedData.new
    signed_data.crx_id = digest.digest(key.public_key.to_der)[0...16]
    signed_data = signed_data.encode

    signature_data = String.new(encoding: "ASCII-8BIT")
    signature_data << "CRX3 SignedData\00"
    signature_data << [ signed_data.size ].pack("V")
    signature_data << signed_data
    signature_data << data

    signature = key.sign(digest, signature_data)

    proof = Crx_file::AsymmetricKeyProof.new
    proof.public_key = key.public_key.to_der
    proof.signature = signature

    header_struct = Crx_file::CrxFileHeader.new
    header_struct.sha256_with_rsa = [proof]
    header_struct.signed_header_data = signed_data
    header_struct = header_struct.encode

    header = String.new(encoding: "ASCII-8BIT")
    header << "Cr24"
    header << [ 3 ].pack("V") # version
    header << [ header_struct.size ].pack("V")
    header << header_struct

    return header
  end

  # @param file [String] to write result to
  # @param dir [String] to read extension from
  # @param key [OpenSSL::PKey]
  # @param crxv [String] version of CRX file to create
  # @param erb_binding [Binding] optional if you want to process ERB files
  # @return undefined
  def self.pack_extension (file:, dir:, key: nil, crxv: "v3", erb_binding: nil)
    zip = zip(dir: dir, erb_binding: erb_binding)

    File.open(file, 'wb') do |io|
      io.write self.send(:"header_#{crxv}_extension", zip, key: key)
      io.write zip
    end
  end

  # @param dir [String] to read extension from
  # @param erb_binding [Binding] optional if you want to process ERB files
  # @return [String] the zip file content
  def self.zip(dir:, erb_binding: nil)
    dir_prefix_len = dir.end_with?("/") ? dir.length : dir.length + 1
    zip = StringIO.new
    zip.set_encoding "ASCII-8BIT"
    Zip::OutputStream::write_buffer(zip) do |zio|
      Find.find(dir) do |file|
        if File.file? file
          if erb_binding && file.end_with?(".erb")
            zio.put_next_entry(file[dir_prefix_len...-4])
            erb = ERB.new(File.read file)
            erb.location = file
            zio.write(erb.result(erb_binding))
            Kernel.puts erb.result(erb_binding)
          else
            zio.put_next_entry(file[dir_prefix_len..-1])
            zio.write(File.read(file))
          end
        end
      end
    end
    return zip.string
  end
end
