basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
libdir  = File.join(basedir, 'lib')
require File.join(libdir, 'has_global_session')

config_file = File.join(RAILS_ROOT, 'config', 'global_session.yml')

if File.exist?(config_file)
  # Tie the Configuration module to Rails' filesystem structure
  # and operating environment.
  HasGlobalSession::Configuration.config_file = config_file
  HasGlobalSession::Configuration.environment = RAILS_ENV
  
  require File.join(libdir, 'has_global_session', 'rails')

  # Enable ActionController integration.
  class ActionController::Base
    def self.has_global_session
      include HasGlobalSession::Rails::ActionControllerInstanceMethods
    end
  end
end
