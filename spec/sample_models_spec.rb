require 'rubygems'
require 'active_record'
RAILS_ENV = 'test'
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
    end
    
    create_table 'comments', :force => true do |comment|
      comment.integer 'blog_post_id', 'user_id'
      comment.text    'comment'
    end

    create_table 'users', :force => true do |user|
      user.date   'birthday'
      user.float  'avg_rating'
      user.string 'login', 'password', 'homepage', 'creation_note', 'gender'
      user.text   'bio', 'irc_nick'
    end
  end
end

# Define ActiveRecord classes
class BadSample < ActiveRecord::Base
  validates_presence_of :title
end

class BlogPost < ActiveRecord::Base
  belongs_to :user
end

class Comment < ActiveRecord::Base
  belongs_to :blog_post
  belongs_to :user
end

class User < ActiveRecord::Base
  validates_inclusion_of :gender, :in => %w( m f )
end

# SampleModel configuration
SampleModels.configure BadSample do |b|
  b.title ''
end

SampleModels.default_instance Comment do
  Comment.create(
    :blog_post => BlogPost.default_sample, :comment => 'foobar',
    :user => User.default_sample
  )
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
  
  it 'should set a custom value by the column name' do
    user = User.custom_sample
    blog_post = BlogPost.custom_sample :user_id => user.id
    blog_post.user.should_not == User.default_sample
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
      ActiveRecord::RecordInvalid, /Title can't be blank/
    )
  end
end

describe 'Model with a nil default value' do
  it 'should set that value in default_sample' do
    @user = User.default_sample
    @user.irc_nick.should be_nil
  end
end

