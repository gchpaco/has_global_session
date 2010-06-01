# Stub to invoke real init.rb when HasGlobalSession is installed as a Rails
# plugin.
basedir = File.dirname(__FILE__)
require File.join(basedir, 'rails', 'init')
