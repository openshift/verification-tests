# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'

module Crx_file
  ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

  ##
  # Message Classes
  #
  class CrxFileHeader < ::Protobuf::Message; end
  class AsymmetricKeyProof < ::Protobuf::Message; end
  class SignedData < ::Protobuf::Message; end


  ##
  # File Options
  #
  set_option :optimize_for, ::Google::Protobuf::FileOptions::OptimizeMode::LITE_RUNTIME


  ##
  # Message Fields
  #
  class CrxFileHeader
    repeated ::Crx_file::AsymmetricKeyProof, :sha256_with_rsa, 2
    repeated ::Crx_file::AsymmetricKeyProof, :sha256_with_ecdsa, 3
    optional :bytes, :signed_header_data, 10000
  end

  class AsymmetricKeyProof
    optional :bytes, :public_key, 1
    optional :bytes, :signature, 2
  end

  class SignedData
    optional :bytes, :crx_id, 1
  end

end

