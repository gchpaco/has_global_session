basedir = File.dirname(__FILE__)
require File.join(basedir, 'lib', 'has_global_session')

# Enable Rails integration if Rails is loaded
if defined?(ActionController::Base)
  class ActionController::Base
    def self.has_global_session
      include HasGlobalSession::ActionControllerInstanceMethods
      after_filter  :global_session_update_cookie
    end
  end
end