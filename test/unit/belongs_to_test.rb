require File.dirname(__FILE__) + "/../test_helper"

class BelongsToTest < SampleModelsTestCase
  def test_associated_with_belongs_to_recipient_by_default
    assert_difference('BlogPost.count') do
      blog_post = BlogPost.sample
      assert blog_post.user
      assert blog_post.user.is_a?(User)
    end
  end
  
  def test_sets_a_custom_value_by_association_name
    user = nil
    assert_difference('User.count') do
      user = User.sample
    end
    assert_difference('BlogPost.count') do
      assert_no_difference('User.count') do
        blog_post = BlogPost.sample :user => user
        assert_equal user, blog_post.user
      end
    end
  end
  
  def test_sets_a_custom_value_by_column_name
    user = nil
    assert_difference('User.count') do
      user = User.sample
    end
    assert_difference('BlogPost.count') do
      assert_no_difference('User.count') do
        blog_post = BlogPost.sample :user_id => user.id
        assert_equal user, blog_post.user
      end
    end
  end
  
  def test_sets_a_custom_nil_value_by_association_name
    assert_difference('Show.count') do
      show = Show.sample :network => nil
      assert_nil show.network
      assert_nil show.network_id
    end
  end  
  
  def test_sets_a_custom_nil_value_by_column_name
    assert_difference('Show.count') do
      show = Show.sample :network_id => nil
      assert_nil show.network
      assert_nil show.network_id
    end
  end
  
  def test_has_no_problem_with_circular_associations
    assert_difference('User.count') do
      assert User.sample.favorite_blog_post.is_a?(BlogPost)
    end
    assert_difference('BlogPost.count') do
      assert BlogPost.sample.user.is_a?(User)
    end
  end
  
  def test_allows_creation_of_a_custom_associated_instance_with_a_hash
    assert_difference('Show.count') do
      assert_difference('Network.count') do
        show = Show.sample(
          :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
        )
        assert_equal "The Daily Show", show.name
        assert_equal 'Comedy Central', show.network.name
      end
    end
  end

  def test_assigns_association_if_a_value_is_passed_in_as_the_first_argument
    user = nil
    assert_difference('User.count') do
      user = User.sample
    end
    assert_difference('BlogPost.count') do
      assert_no_difference('User.count') do
        blog_post = BlogPost.sample(user, :title => 'some title')
        assert_equal user, blog_post.user
        assert_equal 'some title', blog_post.title
      end
    end
  end

  def test_creates_associated_records_with_shortcuts
    network = nil
    assert_difference('Network.count') do
      network = Network.sample
    end
    assert_difference('Video.count') do
      assert_difference('Show.count') do
        assert_no_difference('Network.count') do
          video = Video.sample(:show => [network, {:name => "Jersey Shore"}])
          assert_equal network, video.show.network
          assert_equal "Jersey Shore", video.show.name
        end
      end
    end
  end
  
  def test_unique_belongs_to_should_be_unique_every_time
    video_ids = {}
    10.times do
      created = VideoTakedownEvent.sample
      assert_nil video_ids[created.video_id]
      video_ids[created.video_id] = true
    end
  end
end
