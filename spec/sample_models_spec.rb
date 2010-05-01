require File.dirname(__FILE__) + "/../spec_or_test/setup"
require 'test/unit/assertions'

class Spec::Example::ExampleGroup
  include Test::Unit::Assertions
end

initialize_db

require File.dirname(__FILE__) + "/../spec_or_test/specs_or_test_cases"

describe 'Model with a triangular belongs-to association' do
  it 'should set unspecified association values to the same default instance' do
    video = Video.sample :show => {:name => 'House'}
    video.show.name.should == 'House'
    video.show.network.should_not be_nil
    video.network.should_not be_nil
    video.show.network.should == video.network
  end
end

describe 'Model with a redundant but validated association' do
  it 'should use before_save to reconcile instance issues' do
    video1 = Video.sample :episode => {:name => 'The one about the parents'}
    video1.episode.show.should == video1.show
    video2 = Video.sample :show => {:name => 'South Park'}
    video2.episode.show.should == video2.show
    video2.show.name.should == 'South Park'
  end
  
  it 'should not try to prefill the 2nd-hand association with another record' do
    show = Show.sample(
      :name => 'The Daily Show', :network => {:name => 'Comedy Central'}
    )
    video = Video.sample :show => {:name => 'House'}
    video.show.name.should == 'House'
  end
end

describe 'Model with a unique string attribute' do
  it 'should use sequences to ensure that the attribute is unique every time you call create_sample' do
    ids = []
    logins = []
    10.times do
      custom = User.create_sample
      ids.should_not include(custom.id)
      ids << custom.id
      logins.should_not include(custom.login)
      logins << custom.login
    end
  end
end


=begin
# Create the DB schema
silence_stream(STDOUT) do
  ActiveRecord::Schema.define do
    create_table 'appointments', :force => true do |appointment|
      appointment.datetime 'time'
    end
    
    create_table 'bad_samples', :force => true do |bad_sample|
      bad_sample.string 'title'
    end
    
    create_table 'blog_posts', :force => true do |blog_post|
      blog_post.integer 'user_id', 'merged_into_id', 'category_id',
                        'comments_count', 'category_ranking'
      blog_post.string  'title'
    end
    
    create_table "blog_post_tags", :force => true do |t|
      t.integer "blog_post_id"
      t.integer "tag_id"
    end

    create_table 'categories', :force => true do |category|
    end
    
    create_table 'comments', :force => true do |comment|
      comment.integer 'blog_post_id', 'user_id'
      comment.text    'comment'
      comment.boolean 'flagged_as_spam', :default => false
    end
    
    create_table 'episodes', :force => true do |episode|
      episode.integer 'show_id'
      episode.string  'name'
    end
    
    create_table 'force_network_on_creates', :force => true do |video|
      video.integer 'show_id', 'network_id'
    end
    
    create_table 'networks', :force => true do |network|
      network.string 'name'
    end
    
    create_table 'shows', :force => true do |show|
      show.string  'name'
      show.integer 'network_id'
    end
    
    create_table "tags", :force => true do |t|
      t.string  "tag"
    end

    create_table 'this_or_thats', :force => true do |this_or_that|
      this_or_that.integer 'show_id', 'network_id'
    end

    create_table 'users', :force => true do |user|
      user.date    'birthday'
      user.float   'avg_rating'
      user.string  'login', 'password', 'homepage', 'creation_note', 'gender',
                   'email', 'first_name', 'last_name', 'crypted_password'
      user.text    'bio', 'irc_nick'
      user.integer 'favorite_blog_post_id'
    end
    
    create_table 'videos', :force => true do |video|
      video.string  'name'
      video.integer 'show_id', 'episode_id', 'network_id'
      video.date    'featured_at'
    end
    
    create_table 'video_favorites', :force => true do |video_favorite|
      video_favorite.integer 'user_id', 'video_id'
    end
    
    create_table 'video_takedown_events', :force => true do |vte|
      vte.integer 'video_id'
    end
  end
end

# Define ActiveRecord classes
class Appointment < ActiveRecord::Base
  validates_uniqueness_of :time
end

class BadSample < ActiveRecord::Base
  validates_presence_of :title
end

class BlogPost < ActiveRecord::Base
  belongs_to :category
  belongs_to :merged_into,
             :class_name => 'BlogPost', :foreign_key => 'merged_into_id'
  belongs_to :user
  has_many :blog_post_tags
  has_many :tags, :through => :blog_post_tags
  
  validates_presence_of :category_id, :if => :category_ranking
  validates_presence_of :user_id
end

class BlogPostTag < ActiveRecord::Base
  belongs_to :blog_post
  belongs_to :tag
end

class Category < ActiveRecord::Base
end

class Comment < ActiveRecord::Base
  belongs_to :blog_post
  belongs_to :user
  
  validates_presence_of :blog_post_id
  validates_presence_of :user_id
  validates_presence_of :comment, :if => Proc.new { |c| c.user_id? }
end

class Episode < ActiveRecord::Base
  belongs_to :show
  
  validates_presence_of :show_id
end

class ForceNetworkOnCreate < ActiveRecord::Base
  belongs_to :network
  belongs_to :show
end

class Network < ActiveRecord::Base
end

class Show < ActiveRecord::Base
  validates_uniqueness_of :name
  
  belongs_to :network
end

class Tag < ActiveRecord::Base
  validates_uniqueness_of :tag
  
  has_many :blog_post_tags
  has_many :blog_posts, :through => :blog_post_tags
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

  # Some boilerplate from restful_authentication
  attr_accessor :password

  validates_presence_of     :login, :email
  validates_presence_of     :password,
                            :if => :password_required?
  validates_presence_of     :password_confirmation,
                            :if => :password_required?
  validates_length_of       :password,
                            :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,
                            :if => :password_required?
  validates_length_of       :login, :within => 3..40
  validates_length_of       :email, :within => 3..100
  validates_uniqueness_of   :login, :email, :case_sensitive => false

  validates_email_format_of :email
  validates_inclusion_of    :gender, :in => %w( m f )
  
  def password_required?
    crypted_password.blank? || !password.blank?
  end
end

class Video < ActiveRecord::Base
  belongs_to :show
  belongs_to :network
  belongs_to :episode
  
  def validate
    if episode && episode.show_id != show_id
      errors.add "needs same show as the episode"
    end
  end
end

class VideoFavorite < ActiveRecord::Base
  belongs_to :video
  belongs_to :user
  
  validates_presence_of :user_id, :video_id
  validates_uniqueness_of :video_id, :scope => :user_id
end

class VideoTakedownEvent < ActiveRecord::Base
  belongs_to :video
  
  validates_presence_of   :video_id
  validates_uniqueness_of :video_id
end

# SampleModel configuration
SampleModels.configure BadSample do |b|
  b.default.title ''
end

SampleModels.configure BlogPost do |bp|
  bp.default.category         nil
  bp.default.category_ranking nil
  bp.force_unique             :title
end

SampleModels.configure Episode do |ep|
  ep.force_unique :name
end

SampleModels.configure ForceNetworkOnCreate do |force|
  force.force_on_create :network
end

SampleModels.configure ThisOrThat do |this_or_that|
  this_or_that.before_save do |tot|
    if tot.show.nil? and tot.network.nil?
      tot.network = Network.sample
    end
  end
  this_or_that.default.network      nil
  this_or_that.default.or_the_other 'something else'
  this_or_that.force_on_create      :show
end

SampleModels.configure User do |user|
  user.default do |default|
    default.creation_note { "Started at #{ Time.now.to_s }" }
    default.homepage      'http://www.test.com/'
    default.irc_nick      nil
  end
  user.default_to_nil :first_name, :last_name
  user.before_save { |u| u.password_confirmation = u.password if u.password }
end

SampleModels.configure Video do |video|
  video.before_save { |v| v.show = v.episode.show if v.episode }
  video.force_unique :featured_at
end

# Actual specs start here ...

describe 'Model with a unique string attribute' do
  it 'should find the previously existing instance for repeated calls of .sample' do
    user = User.sample
    user_prime = User.sample
    user.should == user_prime
    user.login.should == user_prime.login
  end
  
  it 'should find an existing record by unique fields and change other if necessary' do
    User.destroy_all
    user = User.create!(
      :login => 'Test login', :homepage => 'http://www.google.com/',
      :gender => 'f', :email => 'foo@bar.com', :crypted_password => 'asdf'
    )
    user_prime = User.sample
    user_prime.login.should == user.login
    user_prime.homepage.should == 'http://www.test.com/'
    user.reload
    user.homepage.should == 'http://www.test.com/'
  end
  
  it 'should be able to modify other fields on the previously saved record if you specify the unique field' do
    user = User.sample
    user_prime = User.sample :login => user.login, :irc_nick => 'test_irc_nick'
    user_prime.id.should == user.id
    user_prime.irc_nick.should == 'test_irc_nick'
    user.reload
    user.irc_nick.should == 'test_irc_nick'
  end
  
  it 'should know to create a new sample if any other fields are passed in' do
    user = User.sample :password => 'password'
    user.login.should_not == 'Test login'
  end
end

describe 'Model with a unique time attribute' do
  it 'should create a random unique value each time you call create_sample' do
    times = {}
    10.times do
      custom = Appointment.create_sample
      times[custom.time].should be_nil
      times[custom.time] = true
    end
  end
end

describe 'Model with a unique associated attribute' do
  it 'should create a random unique associated record each time you call create_sample' do
    video_ids = {}
    10.times do
      created = VideoTakedownEvent.create_sample
      video_ids[created.video_id].should be_nil
      video_ids[created.video_id] = true
    end
  end
end

describe 'Model with a unique scoped associated attribute' do
  it 'should create a new instance when you create_sample with the same scope variable as before' do
    video_fav1 = VideoFavorite.sample
    video_fav2 = VideoFavorite.create_sample :user => video_fav1.user
    video_fav1.should_not == video_fav2
    video_fav1.user.should == video_fav2.user
    video_fav1.video.should_not == video_fav2.video
  end
end

describe 'Model configuration with a bad field name' do
  it 'should raise a useful error message' do
    lambda {
      SampleModels.configure BadSample do |b|
        b.default.foobar ''
      end
    }.should raise_error(
      NoMethodError, /undefined method `foobar' for BadSample/
    )
  end
end

describe 'Model with :force_on_create' do
  it 'should create with that association, instead of creating without and then updating after' do
    this_or_that = ThisOrThat.sample
    this_or_that.network.should be_nil
    this_or_that.show.should_not be_nil
  end
  
  it 'should allow a custom sample for the forced assoc' do
    show = Show.sample
    this_or_that = ThisOrThat.sample :show => show
    this_or_that.show.should == show
  end
  
  it 'should work with before_save, associations, and foreign keys' do
    this_or_that = ThisOrThat.sample :network => Network.sample, :show => nil
    this_or_that.show.should be_nil
    this_or_that.network.should_not be_nil
  end

  it "should choose the same instance for the forced association even if other associations are customized" do
    forced = ForceNetworkOnCreate.sample(
      :show => {:name => 'Arrested Development'}
    )
    forced.network.should_not be_nil
    forced.network.should == forced.show.network
  end
  
  it 'should allow you to set that association to nil' do
    forced = ForceNetworkOnCreate.sample :network => nil
    forced.network.should be_nil
  end
  
  it 'should let you customize the forced association' do
    forced = ForceNetworkOnCreate.sample :network => {:name => 'VH1'}
    forced.network.name.should == 'VH1'
  end
  
  it 'should let you customize the forced association by ID' do
    bravo = Network.sample :name => 'Bravo'
    forced = ForceNetworkOnCreate.sample :network_id => bravo.id
    forced.network.name.should == 'Bravo'
  end
end

describe 'Model with an attr_accessor' do
  it 'should returned the default configured value' do
    ThisOrThat.sample.or_the_other.should == 'something else'
  end
  
  it 'should override for a custom sample' do
    custom = ThisOrThat.sample :or_the_other => 'hello world'
    custom.or_the_other.should == 'hello world'
  end
end

describe 'Model configured with .force_unique' do
  it 'should return the same instance when called twice with no custom attrs' do
    bp1 = BlogPost.sample
    bp1.title.should == 'Test title'
    bp2 = BlogPost.sample
    bp2.title.should == bp1.title
    bp2.should == bp1
  end
  
  it 'should generated a new value for sample calls with custom attrs' do
    bp = BlogPost.sample :user => {:login => 'francis'}
    bp.title.should_not == 'Test title'
  end
  
  it 'should allow nil uniqued attribute if the model allows' do
    video = Video.sample :featured_at => nil
    video.featured_at.should be_nil
  end
  
  it 'should not get confused by a previous record and nil uniqued attributes' do
    Video.destroy_all
    prev_video = Video.create! :featured_at => Date.today
    new_video = Video.sample :featured_at => nil, :name => 'my own name'
    new_video.id.should_not == prev_video.id
    new_video.featured_at.should be_nil
    new_video.name.should == 'my own name'
    new_video.reload
    new_video.featured_at.should be_nil
    new_video.name.should == 'my own name'
  end
end

describe 'SampleModels::Attributes' do
  it 'should work with before_save, associations, and foreign keys' do
    attributes = SampleModels::Attributes.new(
      ThisOrThat, false, :network => Network.sample, :show => nil
    )
    attributes.required.has_key?(:network_id).should be_false
    attributes.required[:network].should_not be_nil
  end
end

describe "Model when its default associated record has been deleted" do
  it 'should just create a new one' do
    ep1 = Episode.sample :name => 'funny'
    ep1.show.destroy
    ep2 = Episode.sample :name => 'funnier'
    ep2.show.should_not be_nil
  end
  
  it "should just create a new one even if the association is not validated to be present" do
    show1 = Show.sample :name => "Oh no you didn't"
    show1.network.destroy
    show2 = Show.sample :name => "Don't go there"
    show2.network.should_not be_nil
  end
end

describe 'Model.sample when a instance already exists in the DB but has different attributes from the default' do
  it 'should not update those different attributes' do
    User.destroy_all
    user1 = User.create!(
      :birthday => Date.new(1960, 1, 1), :avg_rating => 99.99,
      :login => 'Test login', :crypted_password => 'foobar', :gender => 'f',
      :email => 'joebob@email.com', :bio => "here's my bio"
    )
    user2 = User.sample
    user1.id.should == user2.id
    user2.birthday.should == Date.new(1960, 1, 1)
    user2.avg_rating.should == 99.99
    user2.crypted_password.should == 'foobar'
    user2.gender.should == 'f'
    user2.email.should == 'joebob@email.com'
    user2.bio.should == "here's my bio"
  end
end

describe 'Model with an association that validates presence :if => [method], but is configured to nil' do
  it 'should set the association to nil by default' do
    bp = BlogPost.sample
    bp.category.should be_nil
    bp.category_id.should be_nil
  end
  
  it 'should also set the association to nil even when other atts are set custom' do
    bp = BlogPost.sample :title => "That shore was funny"
    bp.category.should be_nil
    bp.category_id.should be_nil
  end
  
  it 'should set the association early on if the :if evaluates to true' do
    bp = BlogPost.sample :category_ranking => 99
    bp.category.should_not be_nil
    bp.category_id.should_not be_nil
  end
end

describe 'Model with a has-many through association' do
  it 'should not interfere with standard instance assignation' do
    funny = Tag.sample :tag => 'funny'
    bp = BlogPost.sample :tags => [funny]
    bp.tags.size.should == 1
    bp.tags.first.tag.should == 'funny'
  end
  
  it 'should make it possible to assign as hashes' do
    bp = BlogPost.sample :tags => [{:tag => 'funny'}]
    bp.tags.size.should == 1
    bp.tags.first.tag.should == 'funny'
  end
end

describe 'Model with an invalid default field' do
  it "should raise an error when sample is called" do
    BadSample.destroy_all
    lambda { BadSample.sample }.should raise_error(
      RuntimeError,
      /BadSample validation failed: Title can't be blank/
    )
  end
end

=end
