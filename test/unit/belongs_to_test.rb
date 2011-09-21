require File.dirname(__FILE__) + "/../test_helper"

class BelongsToTest < Test::Unit::TestCase
  def test_associated_with_belongs_to_recipient_by_default
    blog_post = BlogPost.sample
    assert blog_post.user
    assert blog_post.user.is_a?(User)
  end
  
  def test_sets_a_custom_value_by_association_name
    user = User.sample
    blog_post = BlogPost.sample :user => user
    assert_equal user, blog_post.user
  end
  
  def test_sets_a_custom_value_by_column_name
    user = User.sample
    blog_post = BlogPost.sample :user_id => user.id
    assert_equal user, blog_post.user
  end
  
  def test_sets_a_custom_nil_value_by_association_name
    show = Show.sample :network => nil
    assert_nil show.network
    assert_nil show.network_id
  end  
  
  def test_sets_a_custom_nil_value_by_column_name
    show = Show.sample :network_id => nil
    assert_nil show.network
    assert_nil show.network_id
  end
  
  def test_has_no_problem_with_circular_associations
    assert User.sample.favorite_blog_post.is_a?(BlogPost)
    assert BlogPost.sample.user.is_a?(User)
  end  
end
