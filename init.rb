# Include hook code here

basedir = File.dirname(__FILE__)
require File.join(basedir, 'lib', 'has_global_session')

class ActionController::Base
  def self.has_global_session
    include HasGlobalSession::InstanceMethods

    before_filter :global_session_initialize
    after_filter  :global_session_update
  end
end