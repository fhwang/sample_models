describe "Model.sample" do
  it 'should allow overrides of all fields in sample' do
    user = User.sample(
      :homepage => 'http://mysite.com/', :password => 'myownpassword'
    )
    assert_equal 'http://mysite.com/', user.homepage
    assert_equal 'myownpassword', user.password
  end
  
  it 'should pick the first value given in a validates_inclusion_of' do
    user = User.sample
    assert_equal 'f', user.gender
  end
  
  it "should raise the standard validation error if you break the model's validates_inclusion_of validation" do
    assert_raise(ActiveRecord::RecordInvalid) do
      User.sample(:gender => 'x')
    end
  end
  
  it 'should set emails based on a validation' do
    user = User.sample
    assert_match /^.*@.*\..*/, user.email
  end
  
  it "should raise the standard validation error if you break the model's validates_email_format_of validation" do
    assert_raise(ActiveRecord::RecordInvalid) do
      User.sample(:email => 'call.me')
    end
  end
  
  it 'should not override a boolean default' do
    assert !Comment.sample.flagged_as_spam
  end
end

describe 'Model with a belongs_to association' do
  it 'should be associated with the belongs_to recipient by default' do
    blog_post = BlogPost.sample
    assert blog_post.user
    assert blog_post.user.is_a?(User)
  end
  
  it 'should set a custom value by the association name' do
    user = User.sample
    blog_post = BlogPost.sample :user => user
    assert_equal user, blog_post.user
  end
  
  it 'should set a custom value by the column name' do
    user = User.sample
    blog_post = BlogPost.sample :user_id => user.id
    assert_equal user, blog_post.user
  end
  
  it 'should set a custom nil value by the association name' do
    show = Show.sample :network => nil
    assert_nil show.network
    assert_nil show.network_id
  end
  
  it 'should set a custom nil value by the association name' do
    show = Show.sample :network_id => nil
    assert_nil show.network
    assert_nil show.network_id
  end

  it 'should have no problem with circular associations' do
    assert User.sample.favorite_blog_post.is_a?(BlogPost)
    assert BlogPost.sample.user.is_a?(User)
  end
  
  it 'should allow creation of a custom associated instance with a hash' do
    show = Show.sample(
      :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
    )
    assert_equal "The Daily Show", show.name
    assert_equal 'Comedy Central', show.network.name
  end
end

describe 'Model with a belongs_to association of the same class' do
  before :all do
    @blog_post = BlogPost.sample
  end
  
  it 'should be nil by default' do
    assert_nil @blog_post.merged_into
  end
  
  it 'should not be itself by default' do
    assert_not_equal @blog_post, @blog_post.merged_into
  end
end
