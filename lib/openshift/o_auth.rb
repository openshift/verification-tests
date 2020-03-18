require 'openshift/cluster_resource'
module BushSlicer
  class OAuth < ClusterResource
    RESOURCE = "oauths"
    # pls refer https://github.com/openshift-qe/output_refrences/tree/master/oauth for output example

    # @return a Hash with idp_name as the key and generated value as secret names as values
    #
    # for example:
    #{
    #  "flexy-htpasswd-provider"=>"htpass-secret",
    #  "htpasswd"=>"htpasswd-2nhtj",
    #  "htpasswd-foo"=>"htpasswd-rtc5q",
    #  "htpasswd-bar"=>"htpasswd-8zlqs",
    #  "foobar"=>"htpasswd-txc9w"
    #}
   
    def htpasswds(user: nil, cached: true, quiet: false)
      idps = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'identityProviders')
      # call .compact to remove `nil` compoents (type != 'HTPasswd')
      passwds = idps.map {|i| {i.dig('name') => i.dig('htpasswd', 'fileData', 'name')} if i['type'] == 'HTPasswd' }.compact
      # covert array of hashes to just Hash
      passwds.inject(:merge)
    end
    def idp(user: nil, name:, cached: true, quiet: false)
      idps = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'identityProviders')
      c = idps.find { |c|
        c.dig('name') == name
      } or raise "No idp with name #{name} found."
    end

  end
end
