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
  
  def test_allows_creation_of_a_custom_associated_instance_with_a_hash
    show = Show.sample(
      :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
    )
    assert_equal "The Daily Show", show.name
    assert_equal 'Comedy Central', show.network.name
  end

  def test_assigns_association_if_a_value_is_passed_in_as_the_first_argument
    user = User.sample
    blog_post = BlogPost.sample(user, :title => 'some title')
    assert_equal user, blog_post.user
    assert_equal 'some title', blog_post.title
  end

  def test_creates_associated_records_with_shortcuts
    network = Network.sample
    video = Video.sample(:show => [network, {:name => "Jersey Shore"}])
    assert_equal network, video.show.network
    assert_equal "Jersey Shore", video.show.name
  end
end
