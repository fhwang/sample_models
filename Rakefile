require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rubygems'
gem 'rspec'

ActiveRecordVersions = %w(3.0.1 2.3.10)

desc 'Default: run all tests and specs.'
task :default => [:test, :spec]

desc "Run all specs"
task :spec do
  ActiveRecordVersions.each do |ar_version|
    ENV['ACTIVE_RECORD_VERSION'] = ar_version
    cmd = "rspec spec/sample_models_spec.rb"
    puts ar_version
    puts cmd
    puts `#{cmd}`
  end
end

desc "Run all tests"
task :test do
  ActiveRecordVersions.each do |ar_version|
    cmd = "ACTIVE_RECORD_VERSION=#{ar_version} ruby test/test_sample_models.rb"
    puts cmd
    puts `cd . && #{cmd}`
    puts
  end
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
