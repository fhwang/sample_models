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
  
  it 'should return the same instance with two consecutive calls without arguments' do
    user1 = User.sample
    user2 = User.sample
    assert_equal user1, user2
    assert_equal user1.login, user2.login
  end
  
  it 'should return the same instance with two consecutive calls with the same arguments' do
    user1 = User.sample :homepage => 'http://john.doe.com/'
    user2 = User.sample :homepage => 'http://john.doe.com/'
    assert_equal user1, user2
    assert_equal user1.login, user2.login
  end
  
  it 'should return different instances with two consecutive calls with different arguments' do
    user1 = User.sample :homepage => 'http://john.doe.com/'
    user2 = User.sample :homepage => 'http://jane.doe.com/'
    assert_not_equal user1, user2
    assert_not_equal user1.login, user2.login
  end

  it 'should return a different instance to a later call with more specific attributes' do
    user1 = User.sample
    user2 = User.sample :homepage => 'http://john.doe.com/'
    assert_not_equal user1, user2
    assert_not_equal user1.login, user2.login
  end

  it 'should return the same instance to a later call with less specific attributes' do
    User.destroy_all
    user1 = User.sample(
      :homepage => 'http://mysite.com/', :password => 'myownpassword'
    )
    user2 = User.sample :homepage => 'http://mysite.com/'
    assert_equal user1, user2
    user3 = User.sample
    assert_equal user1, user3
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
  
  it 'should return the same instance with two consecutive calls with the same associated value' do
    user = User.sample
    blog_post1 = BlogPost.sample :user => user
    blog_post2 = BlogPost.sample :user => user
    assert_equal blog_post1, blog_post2
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
  
  it 'should set a custom nil value by the association name, even when there has been a previously created record with default attributes' do
    show1 = Show.sample
    show2 = Show.sample :network => nil
    assert_nil show2.network
  end
  
  it 'should set a custom nil value by the association name, even when there has been a previously created record with that association assigned' do
    show1 = Show.sample :network => Network.sample
    show2 = Show.sample :network => nil
    assert_nil show2.network
  end

  it 'should set a custom nil value by the association ID' do
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
  
  it 'should return the same instance with two consecutive calls with the same association hash' do
    show1 = Show.sample(
      :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
    )
    show2 = Show.sample(
      :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
    )
    assert_equal show1, show2
  end
  
  it 'should return different instances when passed different association hashes' do
    show1 = Show.sample :network => {:name => 'Comedy Central'}
    show2 = Show.sample :network => {:name => 'MTV'}
    assert_not_equal show1, show2 
  end
  
  it 'should gracefully handle destruction of an associated value' do
    blog_post1 = BlogPost.sample
    assert blog_post1.user
    User.destroy_all
    blog_post2 = BlogPost.sample
    assert blog_post2.user
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

describe 'Model with a triangular belongs-to association' do
  it 'should set unspecified association values to the same default instance' do
    video = Video.sample :show => {:name => 'House'}
    assert_equal 'House', video.show.name
    assert video.show.network
    assert video.network
    assert_equal video.network, video.show.network
  end
end

describe 'Model with a redundant but validated association' do
  it 'should use before_save to reconcile instance issues' do
    video1 = Video.sample :episode => {:name => 'The one about the parents'}
    assert_equal video1.show, video1.episode.show
    video2 = Video.sample :show => {:name => 'South Park'}
    assert_equal video2.show, video2.episode.show
    assert_equal 'South Park', video2.show.name
  end
  
  it 'should not try to prefill the 2nd-hand association with another record' do
    show = Show.sample(
      :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
    )
    video = Video.sample :show => {:name => 'House'}
    assert_equal 'House', video.show.name
  end
end

describe 'Model with a unique string attribute' do
  it 'should use sequences to ensure that the attribute is unique every time you call create_sample' do
    ids = []
    logins = []
    10.times do
      custom = User.create_sample
      assert !ids.include?(custom.id)
      ids << custom.id
      assert !logins.include?(custom.login)
      logins << custom.login
    end
  end
  
  it 'should return the same instance if you use the same unique attribute each time' do
    user1 = User.sample :login => 'john_doe'
    user2 = User.sample :login => 'john_doe'
    assert_equal user1, user2
  end
  
  it 'should raise an error if you try to make two different instances with the same string value' do
    User.sample :login => 'john_doe'
    assert_raise(ActiveRecord::RecordInvalid) do
      User.sample(:login => 'john_doe', :homepage => 'http://john.doe.com/')
    end
  end
end

describe 'Model with a unique time attribute' do
  it 'should use sequences to ensure that the attribute is unique every time you call create_sample' do
    times = {}
    10.times do
      custom = Appointment.create_sample
      assert times[custom.time].nil?
      times[custom.time] = true
    end
  end
end

describe 'Model with email and uniqueness validations on the same field' do
  it 'should be able to create a value that satisfies both validations' do
    emails = {}
    10.times do
      custom = User.create_sample
      assert emails[custom.email].nil?
      emails[custom.email] = true
    end
  end
end
