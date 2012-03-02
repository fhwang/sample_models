require File.expand_path(File.join(File.dirname(__FILE__), '/../test_helper'))

class SampleTest < SampleModelsTestCase
  def test_fills_non_validated_non_configured_fields_with_a_non_blank_value
    assert_difference('Appointment.count') do
      appt = Appointment.sample
      assert appt.end_time.is_a?(Time)
    end
    bp_count_before = BlogPost.count
    blog_post = BlogPost.sample
    assert blog_post.average_rating.is_a?(Float)
    assert(BlogPost.count > bp_count_before)
    assert_not_nil(blog_post.body)
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
  
  def test_required_date_field
    episode = Episode.sample
    assert episode.original_air_date.is_a?(Date)
  end

  def test_required_accessor
    user_with_password = UserWithPassword.sample
    assert user_with_password.password.present?
  end
  
  def test_string_which_is_required_to_be_present_and_unique
    # Ensuring that it doesn't get tripped up by a pre-existing record
    User2.destroy_all
    User2.create!(:login => 'login 1')
    User2.sample
  end
  
  def test_create_sample_works_for_now
    assert_difference('Appointment.count') do
      appt = Appointment.create_sample
    end
  end
  
  def test_doesnt_mess_with_created_at_or_updated_at
    blog_post = BlogPost.sample
    assert_in_delta(Time.now.utc, blog_post.created_at, 5)
    assert_in_delta(Time.now.utc, blog_post.updated_at, 5)
  end
  
  def test_dates_and_times_start_from_now_and_sequence_down
    blog_post = BlogPost.sample
    assert(Time.now.utc.advance(:years => -1) < blog_post.published_at)
    episode = Episode.sample
    assert(Date.today - 365 < episode.original_air_date)
  end
end
