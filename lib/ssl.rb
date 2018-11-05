require 'socket'
require 'openssl'

module BushSlicer
  module SSL
    # @param dst [String] the hostname or IP of SSL server
    # @param port [String, Integer] the port number to connect
    # @param hostname [String] hostname for using SNI connection
    # @return [Array] the certificate chain used by secure server;
    #   correct order is host cert first and then deeper down the chain.
    #   In reality though, admins do not always do the right thing
    #   (see https://utcc.utoronto.ca/~cks/space/blog/tech/SSLChainOrder).
    #   So I'm not sure whether the library always returns correct order here.
    def self.get_cert_chain(dst:, port:, hostname: nil)
      context = OpenSSL::SSL::SSLContext.new
      context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      tcp_client = TCPSocket.new dst, port.to_i
      ssl_client = OpenSSL::SSL::SSLSocket.new tcp_client, context
      ssl_client.hostname = hostname if hostname
      ssl_client.connect
      # ssl_client.peer_cert
      chain = ssl_client.peer_cert_chain
      ssl_client.close
      return chain
    end
  end
end
