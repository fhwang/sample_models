require File.dirname(__FILE__) + "/../spec_or_test/setup"
require 'test/unit/assertions'

class Spec::Example::ExampleGroup
  include Test::Unit::Assertions
end

initialize_db

require File.dirname(__FILE__) + "/../spec_or_test/specs_or_test_cases"

