module BushSlicer
  class RoleBinding < ProjectResource
    RESOURCE = 'rolebindings'

    ## Example RoleBinding
    # apiVersion: authorization.openshift.io/v1
    # groupNames: null
    # kind: RoleBinding
    # metadata:
    #   creationTimestamp: 2018-03-07T20:57:48Z
    #   name: admin
    #   namespace: user1-test-prj
    #   resourceVersion: "193439"
    #   selfLink: /apis/authorization.openshift.io/v1/namespaces/user1-test-prj/rolebindings/admin
    #   uid: 310dee61-224a-11e8-ae85-fa163e393b0c
    # roleRef:
    #   name: admin
    # subjects:
    # - kind: User
    #   name: someuser
    # - kind: ServiceAccount
    #   name: deployer
    #   namespace: user1-test-prj
    # - kind: User
    #   name: system:admin
    # - kind: Group
    #   name: system:serviceaccounts:default
    # userNames:
    # - someuser
    # - system:serviceaccounts:user1-test-prj:deployer
    # - system:admin
    # - system:serviceaccounts:default

    def user_names(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet)["userNames"]
    end

    def role_names(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet)["roleRef"]["name"]
    end

    def group_names(user: nil, cached: true, quiet: false)
      raw_resource(user: user, cached: cached, quiet: quiet)["groupNames"]
    end
  end
end
