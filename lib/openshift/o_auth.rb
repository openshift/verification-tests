module BushSlicer
  class OAuth < ClusterResource
    RESOURCE = "oauth"
    # pls refer https://github.com/openshift-qe/output_refrences/tree/master/oauth for output example

    # return a list of Hash with the user defined name mapping to the system generated name
    # for example:
    # [{"flexy-htpasswd-provider"=>"htpass-secret"},
    #  {"htpasswd"=>"htpasswd-2nhtj"},
    #  {"htpasswd-foo"=>"htpasswd-rtc5q"},
    #  {"htpasswd-bar"=>"htpasswd-8zlqs"},
    #  {"foobar"=>"htpasswd-txc9w"}]
    def htpasswds(user: nil, cached: true, quiet: false)
      idps = raw_resource(user: user, cached: cached, quiet: quiet).dig('spec', 'identityProviders')
      passwds = idps.map {|i| {i.dig('name') => i.dig('htpasswd', 'fileData', 'name')} if i['type'] == 'HTPasswd' }
    end

    # return the generated name given a user provided name
    def generated_htpasswd_name(name: nil, user: nil, cached: true, quiet: false)
      htpasswds = self.htpasswds(user: user, cached: cached, quiet: quiet)

      res = htpasswds.select { |k| k.values.first  if k.keys.first == name}
      raise "No matching htpasswd name '#{name}' found!" if res.count == 0
      generated_name = res.first[name]
    end

  end
end
