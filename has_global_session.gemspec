# -*- encoding: utf-8 -*-

require 'rubygems'

spec = Gem::Specification.new do |s|
  s.required_rubygems_version = nil if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")

  s.name    = 'has_global_session'
  s.version = '0.9.4'
  s.date    = '2010-07-20'

  s.authors = ['Tony Spataro']
  s.email   = 'code@tracker.xeger.net'
  s.homepage= 'http://github.com/xeger/has_global_session'
  
  s.summary = %q{Secure single-domain session sharing plugin for Rails.}
  s.description = %q{This plugin for Rails allows several web apps in an authentication domain to share session state, facilitating single sign-on in a distributed web app. It only provides session sharing and does not concern itself with authentication or replication of the user database.}

  s.add_runtime_dependency('uuidtools', [">= 1.0.7"])
  s.add_runtime_dependency('json', [">= 1.1.7"])
  s.add_runtime_dependency('activesupport', [">= 2.1.2"])

  s.add_development_dependency('rspec', [">= 1.3.0"])
  s.add_development_dependency('flexmock', [">= 0.8.6"])
  s.add_development_dependency('actionpack', [">= 2.1.2"])

  basedir = File.dirname(__FILE__)
  candidates = ['has_global_session.gemspec', 'init.rb', 'MIT-LICENSE', 'README.rdoc'] +
            Dir['lib/**/*'] +
            Dir['rails/**/*'] +
            Dir['rails_generators/**/*']
  s.files = candidates.sort
end

if $PROGRAM_NAME == __FILE__
   Gem::Builder.new(spec).build
end
