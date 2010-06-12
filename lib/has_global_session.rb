module HasGlobalSession
  class MissingConfiguration < Exception; end
  class ConfigurationError < Exception; end
  class InvalidSession < Exception; end
  class UnserializableType < Exception; end
  class NoAuthority < Exception; end
end

basedir = File.dirname(__FILE__)
require File.join(basedir, 'has_global_session', 'configuration')
require File.join(basedir, 'has_global_session', 'directory')
require File.join(basedir, 'has_global_session', 'encoding')
require File.join(basedir, 'has_global_session', 'global_session')
require File.join(basedir, 'has_global_session', 'integrated_session')
