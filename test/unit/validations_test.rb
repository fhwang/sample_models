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
end
  
