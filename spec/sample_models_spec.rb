require 'rubygems'
require 'active_record'
RAILS_ENV = 'test'
require 'active_record/base'
require File.dirname(__FILE__) +
        '/vendor/validates_email_format_of/lib/validates_email_format_of'
require File.dirname(__FILE__) + '/../lib/sample_models'

# Configure ActiveRecord
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'mysql'])

# Create the DB schema
silence_stream(STDOUT) do
  ActiveRecord::Schema.define do
    create_table 'bad_samples', :force => true do |bad_sample|
      bad_sample.string 'title'
    end
    
    create_table 'blog_posts', :force => true do |blog_post|
      blog_post.integer 'user_id'
      blog_post.string  'title'
      blog_post.integer 'merged_into_id', 'category_id'
    end
    
    create_table 'categories', :force => true do |category|
    end
    
    create_table 'comments', :force => true do |comment|
      comment.integer 'blog_post_id', 'user_id'
      comment.text    'comment'
    end
    
    create_table 'episodes', :force => true do |episode|
      episode.integer 'show_id'
    end
    
    create_table 'networks', :force => true do |network|
      network.string 'name'
    end
    
    create_table 'shows', :force => true do |show|
      show.string  'name'
      show.integer 'network_id'
    end
    
    create_table 'this_or_thats', :force => true do |this_or_that|
      this_or_that.integer 'show_id', 'network_id'
    end

    create_table 'users', :force => true do |user|
      user.date    'birthday'
      user.float   'avg_rating'
      user.string  'login', 'password', 'homepage', 'creation_note', 'gender',
                   'email'
      user.text    'bio', 'irc_nick'
      user.integer 'favorite_blog_post_id'
    end
    
    create_table 'videos', :force => true do |video|
      video.integer 'show_id', 'episode_id'
    end
  end
end

# Define ActiveRecord classes
class BadSample < ActiveRecord::Base
  validates_presence_of :title
end

class BlogPost < ActiveRecord::Base
  belongs_to :category
  belongs_to :merged_into,
             :class_name => 'BlogPost', :foreign_key => 'merged_into_id'
  belongs_to :user
  
  validates_presence_of :user_id
end

class Category < ActiveRecord::Base
end

class Comment < ActiveRecord::Base
  belongs_to :blog_post
  belongs_to :user
  
  validates_presence_of :blog_post_id
  validates_presence_of :user_id
end

class Episode < ActiveRecord::Base
  belongs_to :show
  
  validates_presence_of :show_id
end

class Network < ActiveRecord::Base
end

class Show < ActiveRecord::Base
  validates_uniqueness_of :name
  
  belongs_to :network
end

class ThisOrThat < ActiveRecord::Base
  belongs_to :show
  belongs_to :network
  
  attr_accessor :or_the_other
  
  def validate
    if show_id.nil? && network_id.nil?
      errors.add "show_id or network_id is required"
    end
  end
end

class User < ActiveRecord::Base
  belongs_to :favorite_blog_post,
             :class_name => 'BlogPost', :foreign_key => 'favorite_blog_post_id'

  validates_email_format_of :email
  validates_inclusion_of    :gender, :in => %w( m f )
  validates_uniqueness_of   :login
end

class Video < ActiveRecord::Base
  belongs_to :show
  belongs_to :episode
  
  def validate
    if episode && episode.show_id != show_id
      errors.add "needs same show as the episode"
    end
  end
end

# SampleModel configuration
SampleModels.configure BadSample do |b|
  b.title ''
end

SampleModels.configure BlogPost do |bp|
  bp.category nil
end

SampleModels.default_instance Comment do
  Comment.create(
    :blog_post => BlogPost.default_sample, :comment => 'foobar',
    :user => User.default_sample
  )
end

SampleModels.configure ThisOrThat, :force_on_create => :show do |this_or_that|
  this_or_that.or_the_other 'something else'
end

SampleModels.configure User do |u|
  u.creation_note { "Started at #{ Time.now.to_s }" }
  u.irc_nick      nil
  u.homepage      'http://www.test.com/'
end

# Actual specs start here ...
describe "Model" do
  it 'should allow overrides of all fields in custom_sample' do
    user = User.custom_sample(
      :homepage => 'http://mysite.com/', :password => 'myownpassword'
    )
    user.homepage.should == 'http://mysite.com/'
    user.password.should == 'myownpassword'
  end

  describe 'default_sample' do
    before :all do
      @user = User.default_sample
    end
    
    it 'should re-create the instance if it was deleted in the database' do
      User.destroy_all
      User.count.should == 0
      user_prime = User.default_sample
      User.count.should == 1
      @user.id.should_not == user_prime.id
    end
  
    it "should return the same instance after multiple calls" do
      user = User.default_sample
      user_prime = User.default_sample
      user.object_id.should == user_prime.object_id
    end
    
    it "should set a field to a configured default" do
      @user.homepage.should == 'http://www.test.com/'
    end
    
    it 'should set floats to 1.0' do
      @user.avg_rating.should == 1.0
    end

    it "should set text fields by default starting with 'test '" do
      @user = User.default_sample
      @user.password.should == 'Test password'
      @user.bio.should == 'Test bio'
    end
    
    it 'should pick the first value given in a validates_inclusion_if' do
      @user.gender.should == 'm'
    end
    
    it 'should set emails based on a validation' do
      @user.email.should match(/^.*@.*\..*/)
    end
  end
end

describe 'Model with a belongs_to association' do
  it 'should be associated with the belongs_to recipient by default' do
    blog_post = BlogPost.default_sample
    blog_post.user.should == User.default_sample
  end
  
  it 'should set a custom value by the association name' do
    user = User.custom_sample
    blog_post = BlogPost.custom_sample :user => user
    blog_post.user.should_not == User.default_sample
  end
  
  it 'should set a custom nil value by the association name' do
    show = Show.custom_sample :network => nil
    show.network.should    be_nil
    show.network_id.should be_nil
  end
  
  it 'should set a custom value by the column name' do
    user = User.custom_sample
    blog_post = BlogPost.custom_sample :user_id => user.id
    blog_post.user.should_not == User.default_sample
  end
  
  it 'should set a custom value by the column name, even when the default sample has been previously set' do
    User.default_sample # tripped a strange bug
    user = User.custom_sample
    blog_post = BlogPost.custom_sample :user_id => user.id
    blog_post.user.should_not == User.default_sample
  end

  it 'should set a custom nil value by the association name' do
    show = Show.custom_sample :network_id => nil
    show.network.should    be_nil
    show.network_id.should be_nil
  end
  
  it 'should have no problem with circular associations' do
    User.default_sample.favorite_blog_post.should == BlogPost.default_sample
    BlogPost.default_sample.user.should == User.default_sample
  end
  
  it 'should update the default association if it gets deleted' do
    blog_post_before = BlogPost.default_sample
    blog_post_before.user_id.should == User.default_sample.id
    User.destroy_all
    User.find_by_id(blog_post_before.user_id).should be_nil
    blog_post_after = BlogPost.default_sample
    blog_post_after.user_id.should == User.default_sample.id
  end
  
  it 'should allow creation of a custom associated instance with a hash' do
    show = Show.custom_sample(
      :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
    )
    show.name.should == "The Daily Show"
    show.network.should_not == Network.default_sample
    show.network.name.should == 'Comedy Central'
  end
  
  it 'should be able to configure an association as nil by default' do
    ds = BlogPost.default_sample
    ds.category.should be_nil
    ds.category_id.should be_nil
    reloaded_ds = BlogPost.default_sample
    reloaded_ds.category.should be_nil
    reloaded_ds.category_id.should be_nil
  end
end

describe 'Model with a belongs_to association of the same class' do
  before :all do
    @blog_post = BlogPost.default_sample
  end
  
  it 'should be nil by default' do
    @blog_post.merged_into.should be_nil
  end
end
  
describe 'Model with a block for a default field' do
  it 'should evaluate the block every time custom_sample is called' do
    user1 = User.custom_sample
    user1.creation_note.should match( /^Started at/ )
    sleep 1
    user2 = User.custom_sample
    user2.creation_note.should match( /^Started at/ )
    user1.creation_note.should_not == user2.creation_note
  end
end

describe 'Model with a default_instance' do
  it 'should determine the instance by running the default_instance block' do
    comment1 = Comment.default_sample
    comment1.comment.should == 'foobar'
  end
end

describe 'Model with an invalid default field' do
  it "should raise an error when default_sample is called" do
    BadSample.destroy_all
    lambda { BadSample.default_sample }.should raise_error(
      RuntimeError,
      /BadSample validation failed: Title can't be blank/
    )
  end
end

describe 'Model with a nil default value' do
  it 'should set that value in default_sample' do
    @user = User.default_sample
    @user.irc_nick.should be_nil
  end
end

describe 'Model with a redundant but validated association' do
  it 'should create a valid default_sample when the 2nd-degree association already exists' do
    Show.create! :name => 'something to take ID 1'
    Show.create! :name => 'Test name'
    Video.default_sample
  end
end

describe 'Model with a unique value' do
  it 'should retrieve by that unique value for the default instance' do
    User.destroy_all
    user = User.create!(
      :login => 'Test login', :gender => 'f', :email => 'foo@bar.com'
    )
    default_sample = User.default_sample
    default_sample.should == user
    default_sample.gender.should == 'f'
    default_sample.email.should  == 'foo@bar.com'
  end
  
  it 'should create a random unique value for each custom_sample' do
    logins = {}
    10.times do
      custom = User.custom_sample
      logins[custom.login].should be_nil
      logins[custom.login] = true
    end
  end
end

describe 'Model configuration with a bad field name' do
  it 'should raise a useful error message' do
    lambda {
      SampleModels.configure BadSample do |b|
        b.foobar ''
      end
    }.should raise_error(
      NoMethodError, /undefined method `foobar' for BadSample/
    )
  end
end

describe 'Model with :force_on_create' do
  it 'should create with that association, instead of creating without and then updating after' do
    this_or_that = ThisOrThat.default_sample
    this_or_that.network.should_not be_nil
    this_or_that.show.should_not be_nil
  end
  
  it 'should allow a custom sample for the forced assoc' do
    this_or_that = ThisOrThat.custom_sample :show => Show.custom_sample
    this_or_that.show.should_not == Show.default_sample
  end
end

describe 'Model with an attr_accessor' do
  it 'should returned the default configured value' do
    ThisOrThat.default_sample.or_the_other.should == 'something else'
  end
  
  it 'should override for a custom sample' do
    custom = ThisOrThat.custom_sample :or_the_other => 'hello world'
    custom.or_the_other.should == 'hello world'
  end
end
