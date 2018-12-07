module VerificationTests
  class OAuthAccessToken < ClusterResource
    RESOURCE = "oauthaccesstokens"

    # Example token
    # apiVersion: v1
    # clientName: openshift-browser-client
    # expiresIn: 86400000
    # kind: OAuthAccessToken
    # metadata:
    #   creationTimestamp: 2018-02-14T01:47:18Z
    #   name: d27779d794a7aa61d836f794739f7134
    #   resourceVersion: "3293"
    #   selfLink: /oapi/v1/oauthaccesstokens/d27779d794a7aa61d836f794739f7134
    #   uid: fcfbbdb4-2228-33e8-b37f-fa163e5b3dc5
    # userName: user13
    # userUID: fcfbbdb4-2228-33e8-b37f-fa163e5b3dc5

  end
end
