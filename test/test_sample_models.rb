require 'test/unit'
require File.dirname(__FILE__) + "/../spec_or_test/setup"

# auto-convert specs into tests whoooooha
@@test_class_sequence = 1

def describe(desc_name, &block)
  klass = Class.new Test::Unit::TestCase
  Object.const_set "TestClass#{@@test_class_sequence}".to_sym, klass
  @@test_class_sequence += 1
  def klass.it(it_name, &block)
    test_name = "test_" + it_name.gsub(/ /, '_')
    if instance_methods.include?(test_name)
      raise "redundant describe #{it_name.inspect}"
    end
    self.send(:define_method, test_name, &block)
  end
  def klass.before(before_name, &block)
    self.send(:define_method, :setup, &block)
  end
  klass.instance_eval &block
end

initialize_db

require File.dirname(__FILE__) + "/../spec_or_test/specs_or_test_cases"

