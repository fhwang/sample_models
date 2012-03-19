require File.expand_path(File.join(File.dirname(__FILE__), '/../test_helper'))

class PolymorphicBelongsToTest < SampleModelsTestCase
  def test_fills_association_with_anything_from_another_class
    bookmark = Bookmark.sample
    assert_not_nil bookmark.bookmarkable
    assert_equal ActiveRecord::Base, bookmark.bookmarkable.class.superclass
    assert_not_equal Bookmark, bookmark.bookmarkable.class
  end
  
  def test_can_specify_association
    blog_post = BlogPost.sample
    bookmark = Bookmark.sample :bookmarkable => blog_post
    assert_equal blog_post, bookmark.bookmarkable
    assert(
      Bookmark.all(
        :conditions => {:bookmarkable_type => 'BlogPost'}
      ).include?(bookmark)
    )
  end
  
  def test_can_specify_association_with_other_leading_associations
    user = User.sample
    blog_post = BlogPost.sample
    sub = Subscription.sample user, :subscribable => blog_post
    assert_equal user, sub.user
    assert_equal blog_post, sub.subscribable
  end
  
  def test_can_set_default_assoc_value_type
    sub = Subscription.sample
    assert_equal 'BlogPost', sub.subscribable_type
  end
end
