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
    create_table 'blog_posts', :force => true do |blog_post|
      blog_post.string 'title'
    end

    create_table 'users', :force => true do |user|
      user.date   'birthday'
      user.string 'login', 'password', 'homepage', 'creation_note'
      user.text   'bio', 'irc_nick'
    end
  end
end

# Define ActiveRecord classes
class BlogPost < ActiveRecord::Base
  validates_presence_of :title
end

class User < ActiveRecord::Base
end

# SampleModel configuration
SampleModels.configure BlogPost do |bp|
  bp.title ''
end

SampleModels.configure User do |u|
  u.creation_note { "Started at #{ Time.now.to_s }" }
  u.irc_nick      nil
  u.homepage      'http://www.test.com/'
end

# Actual specs start here ...
describe 'BlogPost.default_sample' do
  it "should raise an error since it won't validate" do
    BlogPost.destroy_all
    lambda { BlogPost.default_sample }.should raise_error(
      RuntimeError, /Problem creating BlogPost sample/
    )
  end
end

describe "User.custom_sample" do
  it 'should allow overrides of all fields' do
    user = User.custom_sample(
      :homepage => 'http://mysite.com/', :password => 'myownpassword'
    )
    user.homepage.should == 'http://mysite.com/'
    user.password.should == 'myownpassword'
  end
  
  it 'should defer evaluation of field defaults if a block is passed in' do
    user1 = User.custom_sample
    user1.creation_note.should match( /^Started at/ )
    sleep 1
    user2 = User.custom_sample
    user2.creation_note.should match( /^Started at/ )
    user1.creation_note.should_not == user2.creation_note
  end
end

describe "User.default_sample" do
  before :all do
    @user = User.default_sample
  end
  
  it 'should allow a nil default value' do
    @user.irc_nick.should be_nil
  end
  
  it "should set text fields by default starting with 'test '" do
    @user.password.should == 'Test password'
    @user.bio.should == 'Test bio'
  end
  
  it "should set homepage to a configured default" do
    @user.homepage.should == 'http://www.test.com/'
  end
  
  it "should return the same instance after multiple calls" do
    user_prime = User.default_sample
    @user.object_id.should == user_prime.object_id
  end
end

describe 'User.destroy_all' do
  it 'should clear out the cached instance' do
    default_user1 = User.default_sample
    User.destroy_all
    User.count.should == 0
    default_user2 = User.default_sample
    User.count.should == 1
    default_user1.id.should_not == default_user2.id
  end
end

describe "User.without_default_sample" do
  it 'should setup a context without the default sample' do
    User.default_sample
    initial_user_count = User.count
    User.without_default_sample do
      User.count.should ==( initial_user_count - 1 )
    end
    User.count.should == initial_user_count
  end
end

