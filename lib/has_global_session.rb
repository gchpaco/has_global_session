module HasGlobalSession
  # Indicates that the global session configuration file is missing from disk.
  #
  class MissingConfiguration < Exception; end

  # Indicates that the global session configuration file is missing elements or is
  # malformatted.
  #
  class ConfigurationError < Exception; end

  # Indicates that a client submitted a request with a valid session cookie, but the
  # session ID was reported as invalid by the Directory.
  #
  # See Directory#valid_session? for more information.
  #
  class InvalidSession < Exception; end

  # Indicates that a client submitted a request with a valid session cookie, but the
  # session has expired.
  #
  class ExpiredSession < Exception; end

  # Indicates that a client submitted a request with a session cookie that could not
  # be decoded or decompressed.
  #
  class MalformedCookie < Exception; end

  # Indicates that application code tried to put an unserializable object into the glboal
  # session hash. Because the global session is serialized as JSON and not all Ruby types
  # can be easily round-tripped to JSON and back without data loss, we constrain the types
  # that can be serialized.
  #
  # See HasGlobalSession::Encoding::JSON for more information on serializable types.
  #
  class UnserializableType < Exception; end

  # Indicates that the application code tried to write a secure session attribute or
  # renew the global session. Both of these operations require a local authority
  # because they require a new signature to be computed on the global session.
  #
  # See HasGlobalSession::Configuration and HasGlobalSession::Directory for more
  # information.
  #
  class NoAuthority < Exception; end
end

#Make sure gem dependencies are activated.
require 'uuidtools'
require 'json'
require 'active_support'

#Require the core suite of HasGlobalSession classes and modules
basedir = File.dirname(__FILE__)
require File.join(basedir, 'has_global_session', 'configuration')
require File.join(basedir, 'has_global_session', 'directory')
require File.join(basedir, 'has_global_session', 'encoding')
require File.join(basedir, 'has_global_session', 'global_session')
require File.join(basedir, 'has_global_session', 'integrated_session')
