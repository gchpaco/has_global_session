basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
$: << File.join(basedir, 'lib')

require 'flexmock'

require 'has_global_session'
