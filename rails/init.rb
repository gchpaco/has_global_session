basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require File.join(basedir, 'lib', 'has_global_session')

config_file = File.join(RAILS_ROOT, 'config', 'global_session.yml')

if File.exist?(config_file)
  # Tie the Configuration module to Rails' filesystem structure
  # and operating environment.
  HasGlobalSession::Configuration.config_file = config_file
  HasGlobalSession::Configuration.environment = RAILS_ENV

  require File.join(basedir, 'rails', 'action_controller_instance_methods')

  # Enable ActionController integration.
  class ActionController::Base
    def self.has_global_session
      include HasGlobalSession::ActionControllerInstanceMethods
      after_filter  :global_session_update_cookie
    end
  end
end
