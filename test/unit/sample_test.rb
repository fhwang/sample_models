require File.dirname(__FILE__) + "/../test_helper"

class SampleTest < SampleModelsTestCase
  def test_fills_non_validated_non_configured_fields_with_a_non_blank_value
    assert_difference('Appointment.count') do
      appt = Appointment.sample
      assert appt.end_time.is_a?(Time)
    end
    assert_difference('BlogPost.count') do
      blog_post = BlogPost.sample
      assert blog_post.average_rating.is_a?(Float)
    end
    assert_difference('Show.count') do
      show = Show.sample
      assert show.subscription_price.is_a?(Integer)
    end
    assert_difference('Network.count') do
      network = Network.sample
      assert network.name.is_a?(String)
    end
  end
  
  def test_allows_overrides_of_all_fields
    assert_difference('User.count') do
      user = User.sample(
        :homepage => 'http://mysite.com/', :password => 'myownpassword'
      )
      assert_equal 'http://mysite.com/', user.homepage
      assert_equal 'myownpassword', user.password
    end
  end
  
  def test_picks_a_value_given_in_a_validates_inclusion_of
    assert_difference('User.count') do
      user = User.sample
      assert(%(m f).include?(user.gender))
    end
  end
  
  def test_cant_override_validations
    assert_no_difference('User.count') do
      assert_raise(ActiveRecord::RecordInvalid) do
        User.sample(:gender => 'x')
      end
    end
    assert_no_difference('User.count') do
      assert_raise(ActiveRecord::RecordInvalid) do
        User.sample(:email => 'call.me')
      end
    end
  end
  
  def test_set_emails
    assert_difference('User.count') do
      user = User.sample
      assert_match /^.*@.*\..*/, user.email
    end
  end
  
  def test_doesnt_override_a_db_default
    assert_difference('Comment.count') do
      assert !Comment.sample.flagged_as_spam
    end
  end
  
  def test_returns_a_new_instance_with_every_sample_call
    assert_difference('User.count', 2) do
      assert(User.sample != User.sample)
    end
  end
  
  def test_unique_string_attribute
    logins = []
    10.times do
      custom = User.sample
      assert !logins.include?(custom.login)
      logins << custom.login
    end
  end
  
  def test_unique_time_attribute
    times = {}
    10.times do
      custom = Appointment.sample
      assert times[custom.start_time].nil?
      times[custom.start_time] = true
    end
  end
  
  def test_unique_email_attribute
    emails = {}
    10.times do
      custom = User.sample
      assert emails[custom.email].nil?
      emails[custom.email] = true
    end
  end
end
