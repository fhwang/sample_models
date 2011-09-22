require File.dirname(__FILE__) + "/../test_helper"

class ConfigurationTest < SampleModelsTestCase
  def test_model_with_configured_default
    assert_equal 0, Video.sample.view_count
  end
  
  def test_model_with_configured_default_assoc
    cat = Category.sample
    assert_nil cat.parent
  end
end
