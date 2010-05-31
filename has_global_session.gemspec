# -*- encoding: utf-8 -*-

require 'rubygems'

spec = Gem::Specification.new do |s|
  s.required_rubygems_version = nil if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")

  s.name    = 'has_global_session'
  s.version = '0.9.0'
  s.date    = '2010-06-01'

  s.authors = ['Tony Spataro']
  s.email   = 'code@tracker.xeger.net'
  s.homepage= 'http://github.com/xeger/has_global_session'
  
  s.summary = %q{Cryptographically secure intra-domain session-sharing plugin for Rails.}
  s.description = %q{This Rails plugin allows several Rails web apps that share the same back-end user database to share session state in a cryptographically secure way, facilitating single sign-on in a distributed web app. It only provides session sharing and does not concern itself with authentication or replication of the user database.}

  s.add_runtime_dependency('uuidtools', [">= 2.1.1"])

  basedir = File.dirname(__FILE__)
  candidates = ['has_global_session.gemspec', 'init.rb', 'install.rb', 'MIT-LICENSE', 'README', 'uninstall.rb'] +
            Dir['lib/**/*.rb'] +
            Dir['rails/**/*.rb']
  s.files = candidates.sort
end

if $PROGRAM_NAME == __FILE__
   Gem.manage_gems if Gem::RubyGemsVersion.to_f < 1.0
   Gem::Builder.new(spec).build
end