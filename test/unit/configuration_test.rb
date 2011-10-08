require File.dirname(__FILE__) + "/../test_helper"

class ConfigurationTest < SampleModelsTestCase
  def test_model_with_configured_default
    assert_equal 0, Video.sample.view_count
  end
  
  def test_model_with_configured_default_assoc
    cat = Category.sample
    assert_nil cat.parent
  end
  
  def test_configured_default_assoc_can_be_overridden_by_name
    sports = Category.sample :name => 'Sports'
    soccer = Category.sample :name => 'Soccer', :parent => sports
    assert_equal sports, soccer.parent
  end

  def test_configured_default_assoc_can_be_overridden_by_id
    sports = Category.sample :name => 'Sports'
    soccer = Category.sample :name => 'Soccer', :parent_id => sports.id
    assert_equal sports, soccer.parent
  end
  
  def test_configuration_with_a_bad_field_name_should_raise_NoMethodError
    assert_raises(NoMethodError) do
      SampleModels.configure Category do |category|
        category.foobar.default ''
      end
    end
  end

  def test_force_unique
    bp1 = BlogPost.sample
    bp2 = BlogPost.sample
    assert_not_equal bp1, bp2
    assert_not_equal bp1.published_at, bp2.published_at
  end  
  
  def test_force_unique_allows_nil_uniqued_attr_if_the_underlying_model_allows
    bp = BlogPost.sample :published_at => nil
    assert_nil bp.published_at
  end

  def test_before_save
    assert_difference('Video.count') do
      assert_difference('Episode.count') do
        video1 = Video.sample :episode => {:name => 'The one about the parents'}
        assert video1.show
        assert video1.episode
        assert_equal video1.show, video1.episode.show
      end
    end
    assert_difference('Video.count') do
      assert_difference('Show.count') do
        video2 = Video.sample :show => {:name => 'South Park'}
        assert_equal video2.show, video2.episode.show
        assert_equal 'South Park', video2.show.name
      end
    end
  end
  
  def test_before_save_with_only_the_first_argument
    assert_difference('Appointment.count') do
      Appointment.sample
    end
  end
  
  def test_error_on_bad_configuration
    assert_raise(RuntimeError) do
      SampleModels.configure BlogPost do |b|
        b.title.default ''
      end
    end
  end
  
  def test_validate_uniqueness_with_an_allow_nil_allows_nil_configuration
    User.sample
    user = User.sample
    assert_nil user.external_user
    assert_nil user.external_user_id
  end
  
  def test_attr_accessor_can_have_configured_default
    blog_post = BlogPost.sample
    assert_equal('I am an instance attribute', blog_post.instance_attribute)
  end
  
  def test_belongs_to_configured_to_set_in_a_before_save
    topic = Topic.sample(:name => 'Comedy')
    assert(topic.parent.root?)
  end
end
