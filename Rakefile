require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rubygems'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/unit/*_test.rb']
  t.verbose = true
end

ActiveRecordVersions = %w(2.3.14 3.0.10 3.1.0)

desc "Run all tests, for all tested versions of ActiveRecord"
task :all_tests do
  ActiveRecordVersions.each do |ar_version|
    cmd = "ACTIVE_RECORD_VERSION=#{ar_version} rake test"
    puts cmd
    puts `cd . && #{cmd}`
    puts
  end
end

task :default => :all_tests

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = "sample_models"
  gem.homepage = "http://github.com/fhwang/sample_models"
  gem.license = "MIT"
  gem.summary = %Q{A library for making it extremely fast for Rails developers to set up and save ActiveRecord instances when writing test cases}
  gem.description = %Q{
A library for making it extremely fast for Rails developers to set up and save ActiveRecord instances when writing test cases. It aims to:

* meet all your validations automatically
* only make you specify the attributes you care about
* give you a rich set of features so you can specify associated values as concisely as possible
* do this with as little configuration as possible
}
  gem.email = "francis.hwang@profitably.com"
  gem.authors = ["Francis Hwang"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

