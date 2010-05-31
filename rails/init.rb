# Stub to invoke real init.rb if this plugin is invoked as a Rails GemPlugin
basedir = File.dirname(__FILE__)
require File.join(basedir, '..', 'init')
