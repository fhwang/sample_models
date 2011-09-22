RAILS_ENV = 'test'
require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  exit e.status_code
end

require 'test/setup/schema'
require 'validates_email_format_of'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'sample_models'
require 'test/setup/models'
require 'test/unit'

class SampleModelsTestCase < Test::Unit::TestCase
  def assert_difference(expression, difference = 1, message = nil, &block)
    expressions = Array.wrap expression
  
    exps = expressions.map { |e|
      e.respond_to?(:call) ? e : lambda { eval(e, block.binding) }
    }
    before = exps.map { |e| e.call }
  
    yield
  
    expressions.zip(exps).each_with_index do |(code, e), i|
      error  = "#{code.inspect} didn't change by #{difference}"
      error  = "#{message}.\n#{error}" if message
      assert_equal(before[i] + difference, e.call, error)
    end
  end
  
  def assert_no_difference(expression, message = nil, &block)
    assert_difference expression, 0, message, &block
  end

  def default_test
  end
end
