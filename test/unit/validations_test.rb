require File.expand_path(File.join(File.dirname(__FILE__), '/../test_helper'))

class ValidationsTest < SampleModelsTestCase
  def test_validate_uniqueness_with_an_allow_nil_allows_nil_configuration
    User.sample
    user = User.sample
    assert_nil user.external_user
    assert_nil user.external_user_id
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

  def test_validates_length_of
    token2s = []
    50.times do
      user2 = User2.sample
      assert(user2.token1.length >= 40)
      assert(user2.token2.length <= 4)
      token2s << user2.token2
      assert(user2.token3.length >= 20 && user2.token3.length <= 40)
      assert(user2.token4.length >= 20 && user2.token4.length <= 40)
    end
    assert_equal(token2s.size, token2s.uniq.size)
  end
end
  
