require 'etc'
require 'socket'
# should not require 'common' and any other files from bushslicer, base helpers
#   are fine though

require_relative 'error'

# @note put only very base things here, do not use for configuration settings
module BushSlicer
  # autoload to avoid too much require statements and speed-up load times
  autoload :Dynect, 'launchers/dyn/dynect'
  autoload :Alicloud, 'launchers/alicloud'
  autoload :Amz_EC2, 'launchers/amz'
  autoload :GCE, 'launchers/gce'
  autoload :Azure, 'launchers/azure'
  autoload :OpenStack, "launchers/openstack"
  autoload :VSphere, "launchers/v_sphere"
  autoload :Packet, "launchers/packet"
  autoload :IBMCloud, "launchers/ibmcloud"
  autoload :ARMRdu2, "launchers/a_r_m_rdu2"
  autoload :Rdu_IPI_BM, "launchers/rdu_ipi_bm"
  autoload :OCMCluster, "launchers/o_c_m_cluster"
  autoload :EnvironmentLauncher, "launchers/environment_launcher"
  autoload :PolarShift, "polarshift/autoload"

  autoload :APIAccessor, "api_accessor"
  autoload :LocalProcess, "local_process.rb"
  autoload :OwnThat, "ownthat.rb"
  autoload :Platform, "platform/autoload"
  autoload :IAAS, "iaas/iaas"
  autoload :ResultHash, "result_hash"
  autoload :Environment, "environment"
  autoload :OCMEnvironment, "environment"
  autoload :StaticEnvironment, "environment"

  autoload :RESOURCES, "resources"
  autoload :DockerImage, "openshift/flakes/docker_image"

  HOME = File.expand_path(__FILE__ + "/../..")
  CUCUSHIFT_DIR = ENV['BUSHSLICER_CUCUSHIFT_DIR'] || File.expand_path(HOME + "/features/tierN")
  PRIVATE_DIR = ENV['BUSHSLICER_PRIVATE_DIR'] || File.expand_path(HOME + "/private")
  HOSTNAME = Socket.gethostname.freeze
  LOCAL_USER = Etc.getlogin.freeze

  GIT_HASH = `git rev-parse HEAD --git-dir="#{File.join(HOME,'.git')}"`.
                lines[0].chomp rescue :unknown
  GIT_CUCUSHIFT_HASH =
    `git rev-parse HEAD --git-dir="#{File.join(CUCUSHIFT_DIR,'.git')}"`.
      lines[0].chomp rescue :unknown
  GIT_PRIVATE_HASH =
    `git rev-parse HEAD --git-dir="#{File.join(PRIVATE_DIR,'.git')}"`.
      lines[0].chomp rescue :unknown

  if ENV["NODE_NAME"]
    # likely a jenkins environment
    EXECUTOR_NAME_TEMP = "#{ENV["NODE_NAME"]}-#{ENV["EXECUTOR_NUMBER"]}"
  else
    EXECUTOR_NAME_TEMP = "#{HOSTNAME.split('.')[0]}-#{LOCAL_USER}"
  end
  # EXECUTOR_NAME is used as part of project name and workdir,
  # truncate it as the project name is limited to 63 chars,
  # apppend "x" to make sure it always ends with proper char
  EXECUTOR_NAME = "#{EXECUTOR_NAME_TEMP[0..55]}x".freeze

  START_TIME = Time.now
  TIME_SUFFIX = [
    START_TIME.strftime("%Y"),
    START_TIME.strftime("%m"),
    START_TIME.strftime("%d"),
    START_TIME.strftime("%H:%M:%S")
  ]
end
