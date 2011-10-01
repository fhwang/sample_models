require File.dirname(__FILE__) + "/../test_helper"

class NamedSampleTest < SampleModelsTestCase
  def test_named_sample_fills_default_fields
    bp = BlogPost.sample :funny
    assert_equal 'Funny haha', bp.title
    assert_equal 3.0, bp.average_rating
  end
  
  def test_lets_you_override_fields
    bp = BlogPost.sample :funny, :average_rating => 4.0
    assert_equal 'Funny haha', bp.title
    assert_equal 4.0, bp.average_rating
  end
end
