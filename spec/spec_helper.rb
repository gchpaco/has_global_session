basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
$: << File.join(basedir, 'lib')

require 'rubygems'
require 'flexmock'

require 'has_global_session'

Spec::Runner.configure do |config|
  config.mock_with :flexmock
end

class Keystore
  def initialize()
    @keystore = File.join( Dir.tmpdir, "#{Process.pid}_#{rand(2**32)}" )
    FileUtils.mkdir_p(@keystore)
  end

  def dir
    @keystore
  end

  def create(name, write_private)
    new_key     = OpenSSL::PKey::RSA.generate( 256 )
    new_public  = new_key.public_key.to_pem
    new_private = new_key.to_pem
    File.open(File.join(@keystore, "#{name}.pub"), 'w') { |f| f.puts new_public }
    File.open(File.join(@keystore, "#{name}.key"), 'w') { |f| f.puts new_key } if write_private
  end

  def reset()
    FileUtils.rm_rf(File.join(@keystore, '*'))
  end

  def destroy()
    FileUtils.rm_rf(@keystore)
  end
end
