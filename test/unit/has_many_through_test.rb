require File.dirname(__FILE__) + "/../test_helper"

class HasManyThroughTest < SampleModelsTestCase
  def test_standard_instance_assignment
    Tag.destroy_all
    funny = Tag.sample :tag => 'funny'
    bp = BlogPost.sample :tags => [funny]
    assert_equal 1, bp.tags.size
    assert_equal 'funny', bp.tags.first.tag
  end
  
  def test_hash_assignment
    bp1 = BlogPost.sample :tags => [{:tag => 'funny'}]
    assert_equal 1, bp1.tags.size
    assert_equal 'funny', bp1.tags.first.tag
  end
end
