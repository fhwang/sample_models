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
  
  it 'should set fields that are not validated to non-nil values' do
    user = User.sample
    assert_not_nil user.homepage
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
    blog_post3 = BlogPost.sample :name => 'funny'
    assert blog_post3.user
  end
  
  it "should just create a new instance after destruction even if the association is not validated to be present" do
    show1 = Show.sample :name => "Oh no you didn't"
    show1.network.destroy
    show2 = Show.sample :name => "Don't go there"
    assert_not_nil show2.network
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

describe 'Model with a configured default association' do
  it 'should use that default' do
    cat = Category.sample
    assert_nil cat.parent
  end
  
  it 'should allow that default to be overridden by name' do
    sports = Category.sample :name => 'Sports'
    soccer = Category.sample :name => 'Soccer', :parent => sports
    assert_equal sports, soccer.parent
  end
  
  it 'should allow that default to be overridden by ID' do
    sports = Category.sample :name => 'Sports'
    soccer = Category.sample :name => 'Soccer', :parent_id => sports.id
    assert_equal sports, soccer.parent
  end
end

describe 'Model configuration with a bad field name' do
  it 'should raise a useful error message' do
    assert_raises(NoMethodError) do
      SampleModels.configure Category do |category|
        category.default.foobar ''
      end
    end
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

describe 'Model configured with .force_unique' do
  it 'should return the same instance when called twice with no custom attrs' do
    bp1 = BlogPost.sample
    bp2 = BlogPost.sample
    assert_equal bp1, bp2
    assert_equal bp1.published_at, bp2.published_at
  end
  
  it 'should generated a new value for sample calls with custom attrs' do
    bp1 = BlogPost.sample
    bp2 = BlogPost.sample :user => {:login => 'francis'}
    assert_not_equal bp1, bp2
    assert_not_equal bp1.published_at, bp2.published_at
  end
  
  it 'should allow nil uniqued attribute if the model allows it' do
    bp = BlogPost.sample :published_at => nil
    assert_nil bp.published_at
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
  
  it 'should handle destroys gracefully' do
    v1 = Video.sample
    v1.show.destroy
    v2 = Video.create_sample
    assert_not_nil v2.show
    assert_not_nil v2.episode.show
    assert_equal v2.show, v2.episode.show
  end
  
  it 'should be able to use a before_save with only the first argument' do
    appt = Appointment.sample
  end
end

describe 'Model with a unique associated attribute' do
  it 'should ensure that the attribute is unique every time you call create_sample' do
    video_ids = {}
    10.times do
      created = VideoTakedownEvent.create_sample
      assert_nil video_ids[created.video_id]
      video_ids[created.video_id] = true
    end
  end
end

describe 'Model with a unique scoped associated attribute' do
  it 'should create a new instance when you create_sample with the same scope variable as before' do
    video_fav1 = VideoFavorite.sample
    video_fav2 = VideoFavorite.create_sample :user => video_fav1.user
    assert_not_equal video_fav1, video_fav2
    assert_equal video_fav1.user, video_fav2.user
    assert_not_equal video_fav1.video, video_fav2.video
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

describe "Model when its default associated record has been deleted" do
  it 'should just create a new one' do
    ep1 = Episode.sample :name => 'funny'
    ep1.show.destroy
    ep2 = Episode.sample :name => 'funnier'
    assert_not_nil ep2.show
  end
end

describe 'Model with a has-many through association' do
  it 'should not interfere with standard instance assignation' do
    funny = Tag.sample :tag => 'funny'
    bp = BlogPost.sample :tags => [funny]
    assert_equal 1, bp.tags.size
    assert_equal 'funny', bp.tags.first.tag
  end
  
  it 'should use the has-many through association to know that it needs to create a new instance' do
    BlogPost.destroy_all
    bp1 = BlogPost.sample
    assert bp1.tags.empty?
    funny = Tag.sample :tag => 'funny'
    bp2 = BlogPost.sample :tags => [funny]
    assert_equal %w(funny), bp2.tags.map(&:tag)
    assert_not_equal bp1, bp2
    assert_not_equal bp1.id, bp2.id
    sad = Tag.sample :tag => 'sad'
    bp3 = BlogPost.sample :tags => [sad]
    assert_equal %w(sad), bp3.tags.map(&:tag)
    [bp1, bp2].each do |other_bp|
      assert_not_equal(
        other_bp, bp3, "matched blog post with tags #{other_bp.tags.inspect}"
      )
      assert_not_equal other_bp.id, bp3.id
    end
    bp4 = BlogPost.sample :tags => [funny, sad]
    [bp1, bp2, bp3].each do |other_bp|
      assert_not_equal(
        other_bp, bp4, "matched blog post with tags #{other_bp.tags.inspect}"
      )
      assert_not_equal other_bp.id, bp4.id
    end
    assert_equal 2, bp4.tags.size
    %w(funny sad).each do |t|
      assert bp4.tags.map(&:tag).include?(t)
    end
    bp5 = BlogPost.sample :tags => []
    assert bp5.tags.empty?
  end
  
  it 'should create a later instance based on an empty has-many through association' do
    BlogPost.destroy_all
    funny = Tag.sample :tag => 'funny'
    bp1 = BlogPost.sample :tags => [funny]
    bp2 = BlogPost.sample :tags => []
    assert_not_equal bp1, bp2
  end
  
  it "should create a later instance based on another attribute" do
    BlogPost.destroy_all
    funny = Tag.sample :tag => 'funny'
    bp1 = BlogPost.sample :tags => [funny]
    bp2 = BlogPost.sample :tags => [funny], :title => "really funny"
    assert_not_equal bp1, bp2
  end
  
  it "should not match an earlier instance based on a has-many through array that's a subset of the earlier array" do
    BlogPost.destroy_all
    funny = Tag.sample :tag => 'funny'
    sad = Tag.sample :tag => 'sad'
    bp1 = BlogPost.sample :tags => [funny, sad]
    bp2 = BlogPost.sample :tags => [funny]
    assert_not_equal bp1, bp2
  end
  
  it 'should use the has-many through array to determine it already has a matching record' do
    funny = Tag.sample :tag => 'funny'
    bp1 = BlogPost.sample :tags => [funny]
    bp2 = BlogPost.sample :tags => [funny]
    assert_equal bp1, bp2
    sad = Tag.sample :tag => 'sad'
    bp3 = BlogPost.sample :tags => [funny, sad]
    bp4 = BlogPost.sample :tags => [sad, funny]
    assert_equal bp3, bp4
  end
  
  it 'should make it possible to assign and find as hashes' do
    bp1 = BlogPost.sample :tags => [{:tag => 'funny'}]
    assert_equal 1, bp1.tags.size
    assert_equal 'funny', bp1.tags.first.tag
    bp2 = BlogPost.sample :tags => [{:tag => 'funny'}]
    assert_equal bp1, bp2
  end
  
  it 'should handle a mix of instances and hashes in the array' do
    funny = Tag.sample :tag => 'funny'
    bp = BlogPost.sample :tags => [{:tag => 'sad'}, funny]
    assert_equal 2, bp.tags.size
    %w(sad funny).each do |t|
      assert bp.tags.map(&:tag).include?(t)
    end
  end
end

describe 'Model with an invalid default field' do
  it "should raise an error when a bad configuration is attempted" do
    assert_raise(RuntimeError) do
      SampleModels.configure BlogPost do |b|
        b.title.default ''
      end
    end
  end
end

