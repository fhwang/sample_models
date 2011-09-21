require File.dirname(__FILE__) + "/../test_helper"

class BelongsToTest < Test::Unit::TestCase
  def test_associated_with_belongs_to_recipient_by_default
    blog_post = BlogPost.sample
    assert blog_post.user
    assert blog_post.user.is_a?(User)
  end
end
