require 'rubygems'
require 'rake'
require 'spec/rake/spectask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/clean'

desc "Run unit tests"
task :default => :spec

desc "Run unit tests"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = Dir['**/*_spec.rb']
  t.spec_opts = lambda do
    IO.readlines(File.join(File.dirname(__FILE__), 'spec', 'spec.opts')).map {|l| l.chomp.split " "}.flatten
  end
end

desc 'Generate documentation for the has_global_session plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'has_global_session'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

load File.expand_path(File.join(File.dirname(__FILE__), 'has_global_session.gemspec'))

desc "Build has_global_session gem"
Rake::GemPackageTask.new(SPEC) do |package|
  package.need_zip = true
  package.need_tar = true
end

CLEAN.include('pkg')
