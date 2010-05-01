describe "Model.sample" do
  it 'should allow overrides of all fields in sample' do
    user = User.sample(
      :homepage => 'http://mysite.com/', :password => 'myownpassword'
    )
    assert_equal 'http://mysite.com/', user.homepage
    assert_equal 'myownpassword', user.password
  end
end
