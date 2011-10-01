require File.dirname(__FILE__) + "/../test_helper"

class HasManyThroughTest < SampleModelsTestCase
  def test_standard_instance_assignment
    Tag.destroy_all
    funny = nil
    assert_difference('Tag.count') do
      funny = Tag.sample :tag => 'funny'
    end
    assert_difference('BlogPost.count') do
      assert_no_difference('Tag.count') do
        bp = BlogPost.sample :tags => [funny]
        assert_equal 1, bp.tags.size
        assert_equal 'funny', bp.tags.first.tag
      end
    end
  end
  
  def test_hash_assignment
    Tag.destroy_all
    assert_difference('Tag.count') do
      assert_difference('BlogPost.count') do
        bp1 = BlogPost.sample :tags => [{:tag => 'funny'}]
        assert_equal 1, bp1.tags.size
        assert_equal 'funny', bp1.tags.first.tag
      end
    end
  end
  
  def test_hash_and_record_assignment
    Tag.destroy_all
    funny = nil
    assert_difference('Tag.count') do
      funny = Tag.sample :tag => 'funny'
    end
    assert_difference('BlogPost.count') do
      assert_difference('Tag.count') do
        bp = BlogPost.sample :tags => [{:tag => 'sad'}, funny]
        assert_equal 2, bp.tags.size
        %w(sad funny).each do |t|
          assert bp.tags.map(&:tag).include?(t)
        end
      end
    end
  end
end
