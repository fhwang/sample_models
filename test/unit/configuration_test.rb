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
end
