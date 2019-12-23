require 'atlassian/jwt/version'
require 'jwt'
require 'uri'
require 'cgi'

module Atlassian
  module Jwt
    class << self
      CANONICAL_QUERY_SEPARATOR = '&'
      ESCAPED_CANONICAL_QUERY_SEPARATOR = '%26'

      def decode(token, secret, validate = true, options = {})
        options = {:algorithm => 'HS256'}.merge(options)
        ::JWT.decode(token, secret, validate, options)
      end

      def encode(payload, secret, algorithm = 'HS256', header_fields = {})
        ::JWT.encode(payload, secret, algorithm, header_fields)
      end

      def create_query_string_hash(uri, http_method, base_uri)
        Digest::SHA256.hexdigest(
          create_canonical_request(uri, http_method, base_uri)
        )
      end

      def create_canonical_request(uri, http_method, base_uri)
        uri = URI.parse(uri) unless uri.kind_of? URI
        base_uri = URI.parse(base_uri) unless base_uri.kind_of? URI

        [
          http_method.upcase,
          canonicalize_uri(uri, base_uri),
          canonicalize_query_string(uri.query)
        ].join(CANONICAL_QUERY_SEPARATOR)
      end

      def build_claims(issuer, url, http_method, base_url = '', issued_at = nil, expires = nil, attributes = {})
        issued_at ||= Time.now.to_i
        expires ||= issued_at + 60
        qsh = Digest::SHA256.hexdigest(
          Atlassian::Jwt.create_canonical_request(url, http_method, base_url)
        )

        {
          iss: issuer,
          iat: issued_at,
          exp: expires,
          qsh: qsh
        }.merge(attributes)
      end

      def canonicalize_uri(uri, base_uri)
        path = uri.path.sub(/^#{base_uri.path}/, '')
        path = '/' if path.nil? || path.empty?
        path = '/' + path unless path.start_with? '/'
        path.chomp!('/') if path.length > 1
        path.gsub(CANONICAL_QUERY_SEPARATOR, ESCAPED_CANONICAL_QUERY_SEPARATOR)
      end

      def canonicalize_query_string(query)
        return '' if query.nil? || query.empty?

        query = CGI::parse(query)
        query.delete('jwt')
        query.each do |k, v|
          query[k] = v.map { |a| CGI.escape a }.join(',') if v.is_a? Array
          query[k].gsub!('+', '%20')  # Use %20, not CGI.escape default of "+"
          query[k].gsub!('%7E', '~')  # Unescape "~" per JS tests
        end
        query = Hash[query.sort]
        query.map { |k,v| "#{CGI.escape k}=#{v}" }.join(CANONICAL_QUERY_SEPARATOR)
      end
    end
  end
end
