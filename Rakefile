require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rubygems'
gem 'rspec'
require 'spec/rake/spectask'

desc 'Default: run specs.'
task :default => [:test, :spec]

desc "Run all specs"
task :spec do
  cmd = "spec spec/sample_models_spec.rb"
  puts cmd
  puts `#{cmd}`
end

desc "Run all tests"
Rake::TestTask.new do |t|
  t.test_files = FileList['test/*.rb']
end

desc 'Generate documentation for the sample_models plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'SampleModels'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "sample_models"
    gem.summary = %Q{A library for making it extremely fast for Rails developers to set up and save ActiveRecord instances when writing test cases}
    gem.description = %Q{
A library for making it extremely fast for Rails developers to set up and save ActiveRecord instances when writing test cases. It aims to:

* meet all your validations automatically
* only make you specify the attributes you care about
* give you a rich set of features so you can specify associated values as concisely as possible
* do this with as little configuration as possible
}
    gem.email = "francis.hwang@profitably.com"
    gem.homepage = "http://github.com/fhwang/sample_models"
    gem.authors = ["Francis Hwang"]
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
