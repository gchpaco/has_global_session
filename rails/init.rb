basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
libdir  = File.join(basedir, 'lib')
config_file = File.join(RAILS_ROOT, 'config', 'global_session.yml')

if File.exist?(config_file)
  require File.join(libdir, 'has_global_session')
  require File.join(libdir, 'has_global_session', 'rails')

  # Enable ActionController integration.
  class <<ActionController::Base
    include HasGlobalSession::Rails::ActionControllerClassMethods
  end
end
