ENV['BUSHSLICER_PRIVATE_DIR'] = nil

lib_path = File.expand_path(File.dirname(File.dirname(__FILE__)))
unless $LOAD_PATH.any? {|p| File.expand_path(p) == lib_path}
  $LOAD_PATH.unshift(lib_path)
end

require 'fileutils'
require 'test/unit'
require_relative './ocm'

class MyTest < Test::Unit::TestCase
  def setup
    ENV['OCM_NAME'] = nil
    ENV['OCM_TOKEN'] = nil
    ENV['OCM_URL'] = nil
    ENV['OCM_REGION'] = nil
    ENV['OCM_VERSION'] = nil
    ENV['OCM_LIFESPAN'] = nil
    ENV['AWS_REGION'] = nil
    ENV['AWS_ACCOUNT_ID'] = nil
    ENV['AWS_ACCESS_KEY'] = nil
    ENV['AWS_SECRET_KEY'] = nil
    ENV['AWS_SECRET_ACCESS_KEY'] = nil
    ENV['GIT_OSD_URI'] = nil
  end

  # def teardown
  # end

  def test_default_url
    options = { :token => "abc" }
    ocm = BushSlicer::OCM.new(options)
    assert_equal('https://api.stage.openshift.com', ocm.url)
  end

  def test_default_url_envvars
    ENV['OCM_TOKEN'] = "abc"
    ocm = BushSlicer::OCM.new()
    assert_equal('https://api.stage.openshift.com', ocm.url)
  end

  def test_generating_cluster_data
    options = { :token => "abc" }
    ocm = BushSlicer::OCM.new(options)
    json = ocm.generate_cluster_data('myosd4').to_json
    assert_equal('{"name":"myosd4","managed":true,"multi_az":false,"byoc":false}', json)
  end

  def test_generating_cluster_data_with_region
    options = { :token => "abc", :region => "us-east-1" }
    ocm = BushSlicer::OCM.new(options)
    json = ocm.generate_cluster_data('myosd4').to_json
    assert_equal('{"name":"myosd4","managed":true,"multi_az":false,"byoc":false,"region":{"id":"us-east-1"}}', json)
  end

  def test_generating_cluster_data_with_region_envvars
    ENV['OCM_TOKEN'] = "abc"
    ENV['OCM_REGION'] = "us-east-2"
    ocm = BushSlicer::OCM.new()
    json = ocm.generate_cluster_data('myosd4').to_json
    assert_equal('{"name":"myosd4","managed":true,"multi_az":false,"byoc":false,"region":{"id":"us-east-2"}}', json)
  end

  def test_generating_cluster_data_with_aws_envvars
    ENV['OCM_TOKEN'] = "abc"
    ENV['AWS_REGION'] = "eu-central-1"
    ENV['AWS_ACCOUNT_ID'] = '123456789'
    ENV['AWS_ACCESS_KEY'] = 'AKIAZZ007'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'asdfghjkl/123456'

    ocm = BushSlicer::OCM.new()
    json = ocm.generate_cluster_data('myosd4').to_json
    assert_equal('{"name":"myosd4","managed":true,"multi_az":false,"byoc":true,"region":{"id":"eu-central-1"},"aws":{"account_id":"123456789","access_key_id":"AKIAZZ007","secret_access_key":"asdfghjkl/123456"}}', json)
  end

  def test_generating_json_with_version
    options = { :token => "abc", :version => "4.6.1" }
    ocm = BushSlicer::OCM.new(options)
    json = ocm.generate_cluster_data('myosd4').to_json
    assert_equal('{"name":"myosd4","managed":true,"multi_az":false,"byoc":false,"version":{"id":"openshift-v4.6.1"}}', json)
  end

  def test_generating_cluster_data_with_lifespan
    options = { :token => "abc", :lifespan => "25h" }
    ocm = BushSlicer::OCM.new(options)
    json = ocm.generate_cluster_data('myosd4').to_json
    time = Time.now + 60 * 60 * 25
    year = time.strftime("%Y")
    month = time.strftime("%m")
    day = time.strftime("%d")
    assert_match(/.*"expiration_timestamp":"#{year}-#{month}-#{day}T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z".*/, json)
  end

  def test_generating_cluster_data_with_nodes
    options = { :token => "abc", :num_nodes => "8" }
    ocm = BushSlicer::OCM.new(options)
    json = ocm.generate_cluster_data('myosd4').to_json
    assert_equal('{"name":"myosd4","managed":true,"multi_az":false,"byoc":false,"nodes":{"compute":8}}', json)
  end

  def test_executing_shell
    hello_script = "/tmp/hello.sh"
    File.write(hello_script, "#!/bin/sh\n[[ -z \"$1\" ]] && echo \"Specify a name!\" && exit 1; for i in {1..3}; do echo \"Hello $1\"; sleep 5; done")
    File.chmod(0755, hello_script)
    options = { :token => "abc" }
    ocm = BushSlicer::OCM.new(options)
    result = ocm.shell("#{hello_script} World")
    assert_equal("Hello World\nHello World\nHello World\n", result)
    result = ocm.shell("#{hello_script} World", STDOUT)
    assert_equal("", result)
    error = assert_raises(RuntimeError) { ocm.shell("#{hello_script} ") }
    assert_equal("Error when executing '#{hello_script} '. Response: Specify a name!\n", error.message)
    error = assert_raises(RuntimeError) { ocm.shell("#{hello_script} ", STDOUT) }
    assert_equal("Error when executing '#{hello_script} '. Response: ", error.message)
  end

  def test_downloading_ocm_cli
    options = { :token => "abc" }
    ocm = BushSlicer::OCM.new(options)
    ocm_cli = ocm.download_ocm_cli
    assert(File.exists?(ocm_cli), "File '#{ocm_cli}' was not downloaded")
    output = ocm.shell('/tmp/ocm version').strip
    assert_equal("0.1.46", output)
  end

  def test_executing_ocm
    options = { :token => "abc" }
    ocm = BushSlicer::OCM.new(options)
    output = ocm.exec("version")
    assert_equal("0.1.46", output)
    # if we provide some fake ocm-cli
    if ENV['OCM_CLI_URL']
      output = ocm.get_value("osd4-001", "id")
      assert_equal("1ia3pju6itu3oqd8ba6p522858ua49hq", output)
      output = ocm.get_value("osd4-001", "state")
      assert_equal("ready", output)
      output = ocm.get_value("osd4-001", "api.url")
      assert_equal("https://api.osd4-001.w95o.s1.foo.com", output)
      creds = ocm.get_credentials("osd4-001")
      assert_equal("guest", creds["admin"]["user"])
      assert_equal("some-password", creds["admin"]["password"])
    end
  end

  def test_generating_ocpinfo_data
    options = { :token => "abc" }
    ocm = BushSlicer::OCM.new(options)
    result = ocm.generate_ocpinfo_data('https://api.osd4-123.w95o.s1.foo.com:6443/', 'guest', 'some-password')
    assert_equal('osd4-123.w95o.s1.foo.com', result["ocp_domain"])
    assert_equal('https://api.osd4-123.w95o.s1.foo.com:6443', result["ocp_api_url"])
    assert_equal('https://console-openshift-console.apps.osd4-123.w95o.s1.foo.com', result["ocp_console_url"])
    assert_equal('guest', result["user"])
    assert_equal('some-password', result["password"])
    result = ocm.generate_ocpinfo_data('https://api.osd4-123.w95o.s1.foo.com', 'guest', 'some-password')
    assert_equal('osd4-123.w95o.s1.foo.com', result["ocp_domain"])
    assert_equal('https://api.osd4-123.w95o.s1.foo.com:6443', result["ocp_api_url"])
    assert_equal('https://console-openshift-console.apps.osd4-123.w95o.s1.foo.com', result["ocp_console_url"])
    assert_equal('guest', result["user"])
    assert_equal('some-password', result["password"])
  end

  def test_creating_osd
    # only if we provide some fake ocm-cli
    if ENV['OCM_CLI_URL']
      options = { :token => "abc" }
      ocm = BushSlicer::OCM.new(options)
      ocm.create_osd("osd4-001")
      ocpinfo_file = File.join(BushSlicer::Host.localhost.workdir, 'install-dir', 'OCPINFO.yml')
      ocpinfo = YAML.load_file(ocpinfo_file)
      assert_equal('osd4-001.w95o.s1.foo.com', ocpinfo['ocp_domain'])
      assert_equal('https://console-openshift-console.apps.osd4-001.w95o.s1.foo.com', ocpinfo['ocp_console_url'])
      assert_equal('https://api.osd4-001.w95o.s1.foo.com:6443', ocpinfo['ocp_api_url'])
      assert_equal('guest', ocpinfo['user'])
      assert_equal('some-password', ocpinfo['password'])
    end
  end

end
