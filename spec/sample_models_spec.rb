require 'rubygems'
require 'active_record'
RAILS_ENV = 'test'
require File.dirname(__FILE__) + '/../lib/sample_models'

# Configure ActiveRecord
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'memory'])

# Create the DB schema
silence_stream(STDOUT) do
  ActiveRecord::Schema.define do
    create_table 'users', :force => true do |user|
      user.string 'login', 'password', 'homepage'
      user.date 'birthday'
    end
  end
end

# Define ActiveRecord classes
class User < ActiveRecord::Base
end

# SampleModel configuration
SampleModels.configure User do |u|
  u.homepage 'http://www.test.com/'
end

# Actual specs start here ...
describe "User.default_sample" do
  before :all do
    @user = User.default_sample
  end
  
  it "should set text fields by default starting with 'test '" do
    @user.password.should == 'Test password'
  end
  
  it "should set homepage to a configured default" do
    @user.homepage.should == 'http://www.test.com/'
  end
  
  it "should return the same instance after multiple calls" do
    user_prime = User.default_sample
    @user.object_id.should == user_prime.object_id
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
end
