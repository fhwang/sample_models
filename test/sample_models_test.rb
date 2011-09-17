require File.dirname(__FILE__) + "/test_helper"

class SampleTest < Test::Unit::TestCase
  def test_fills_non_validated_non_configured_fields_with_a_non_blank_value
    appt = Appointment.sample
    assert appt.end_time.is_a?(Time)
    blog_post = BlogPost.sample
    assert blog_post.average_rating.is_a?(Float)
    show = Show.sample
    assert show.subscription_price.is_a?(Integer)
    network = Network.sample
    assert network.name.is_a?(String)
  end
  
  def test_allows_overrides_of_all_fields
    user = User.sample(
      :homepage => 'http://mysite.com/', :password => 'myownpassword'
    )
    assert_equal 'http://mysite.com/', user.homepage
    assert_equal 'myownpassword', user.password
  end
  
  def test_picks_a_value_given_in_a_validates_inclusion_of
    user = User.sample
    assert(%(m f).include?(user.gender))
  end
end
