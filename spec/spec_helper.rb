basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
$: << File.join(basedir, 'lib')

require 'tempfile'

require 'rubygems'
require 'flexmock'

require 'has_global_session'

require File.join('has_global_session', 'rails', 'action_controller_instance_methods')

Spec::Runner.configure do |config|
  config.mock_with :flexmock
end

class KeyFactory
  def initialize()
    @keystore = File.join( Dir.tmpdir, "#{Process.pid}_#{rand(2**32)}" )
    FileUtils.mkdir_p(@keystore)
  end

  def dir
    @keystore
  end

  def create(name, write_private)
    new_key     = OpenSSL::PKey::RSA.generate(1024)
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

module SpecHelper
  def mock_config(path, value)
    Configuration.instance_variable_set(:@environment, 'test')    
    hash = Configuration.instance_variable_get(:@config) || {}
    Configuration.instance_variable_set(:@config, hash)
    
    path = path.split('/')
    first_keys = path[0...-1]
    last_key   = path.last
    first_keys.each do |key|
      hash[key] ||= {}
      hash = hash[key]
    end
    hash[last_key] = value
  end

  def reset_mock_config
    Configuration.instance_variable_set(:@config, nil)    
    Configuration.instance_variable_set(:@config_file, nil)
    Configuration.instance_variable_set(:@environment, nil)    
  end
end