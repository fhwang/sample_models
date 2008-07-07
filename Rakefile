require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rubygems'
gem 'rspec'
require 'spec/rake/spectask'

desc 'Default: run specs.'
task :default => :spec

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/*.rb']
end

desc 'Generate documentation for the sample_models plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'SampleModels'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
