RAILS_ENV = 'test'
require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

require 'active_record'
require 'active_record/base'
require 'active_support/core_ext/logger'
require 'active_support/core_ext/module/attribute_accessors'
require 'validates_email_format_of'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'sample_models'

# Configure ActiveRecord
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'mysql'])

def initialize_db
  silence_stream(STDOUT) do
    ActiveRecord::Schema.define do
      create_table 'appointments', :force => true do |appointment|
        appointment.datetime 'start_time', 'end_time'
        appointment.integer 'user_id', 'calendar_id', 'category_id'
      end
    
      create_table 'blog_posts', :force => true do |blog_post|
        blog_post.datetime 'published_at'
        blog_post.integer 'merged_into_id', 'user_id'
        blog_post.string  'title'
        blog_post.float   'average_rating'
      end
    
      create_table "blog_post_tags", :force => true do |t|
        t.integer "blog_post_id"
        t.integer "tag_id"
      end
      
      create_table "bookmarks", :force => true do |t|
        t.integer "bookmarkable_id"
        t.string  "bookmarkable_type"
      end

      create_table 'calendars', :force => true do |appointment|
        appointment.integer 'user_id'
      end

      create_table 'categories', :force => true do |category|
        category.string  'name'
        category.integer 'parent_id'
      end
  
      create_table 'comments', :force => true do |comment|
        comment.boolean 'flagged_as_spam', :default => false
      end
      
      create_table 'episodes', :force => true do |episode|
        episode.integer 'show_id'
        episode.string  'name'
        episode.date    'original_air_date'
      end
      
      create_table 'networks', :force => true do |network|
        network.string 'name'
      end
      
      create_table 'shows', :force => true do |show|
        show.integer 'network_id', 'subscription_price'
        show.string  'name'
      end
      
      create_table 'subscriptions', :force => true do |subscription|
        subscription.integer 'subscribable_id', 'user_id'
        subscription.string  'subscribable_type'
      end

      create_table "tags", :force => true do |t|
        t.string  "tag"
      end

      create_table 'users', :force => true do |user|
        user.integer 'favorite_blog_post_id'
        user.string  'email', 'gender', 'homepage', 'login', 'password'
      end
      
      create_table 'user2s', :force => true do |user2|
        user2.string  'login'
      end
      
      create_table 'user_with_passwords', :force => true do |user|
      end
      
      create_table 'videos', :force => true do |video|
        video.integer 'episode_id', 'show_id', 'network_id', 'view_count'
      end
    
      create_table 'video_favorites', :force => true do |video_favorite|
        video_favorite.integer 'user_id', 'video_id'
      end
    
      create_table 'video_takedown_events', :force => true do |vte|
        vte.integer 'video_id'
      end
    end
  end
end

# ============================================================================
# Define ActiveRecord classes
class Appointment < ActiveRecord::Base
  belongs_to :calendar
  belongs_to :category
  belongs_to :user
  
  validates_presence_of :calendar_id, :user_id
  validates_uniqueness_of :start_time
  validate :validate_calendar_has_same_user_id
  
  def validate_calendar_has_same_user_id
    if calendar.user_id != user_id
      errors.add "Appointment needs same user as the calendar"
    end
  end
end

class BlogPost < ActiveRecord::Base
  has_many   :blog_post_tags
  belongs_to :merged_into,
             :class_name => 'BlogPost', :foreign_key => 'merged_into_id'
  has_many   :tags, :through => :blog_post_tags
  belongs_to :user
  
  validates_presence_of :title
  validates_presence_of :user_id
end

class BlogPostTag < ActiveRecord::Base
  belongs_to :blog_post
  belongs_to :tag
end

class Bookmark < ActiveRecord::Base
  belongs_to :bookmarkable, :polymorphic => true
end

class Calendar < ActiveRecord::Base
  belongs_to :user
  
  validates_presence_of :user_id
end

class Category < ActiveRecord::Base
  belongs_to :parent, :class_name => 'Category'
end

class Comment < ActiveRecord::Base
end

class Episode < ActiveRecord::Base
  belongs_to :show
  
  validates_presence_of :show_id, :original_air_date
end

class Network < ActiveRecord::Base
end

class Show < ActiveRecord::Base
  belongs_to :network
end

class Subscription < ActiveRecord::Base
  belongs_to :subscribable, :polymorphic => true
  belongs_to :user
end

class Tag < ActiveRecord::Base
  validates_uniqueness_of :tag
  
  has_many :blog_post_tags
  has_many :blog_posts, :through => :blog_post_tags
end

class User < ActiveRecord::Base
  belongs_to :favorite_blog_post,
             :class_name => 'BlogPost', :foreign_key => 'favorite_blog_post_id'

  validates_email_format_of :email
  validates_inclusion_of    :gender, :in => %w(f m)
  validates_uniqueness_of   :email, :login, :case_sensitive => false
end

class User2 < ActiveRecord::Base
  validates_presence_of   :login
  validates_uniqueness_of :login
end

class UserWithPassword < ActiveRecord::Base
  attr_accessor :password
  
  validates_presence_of :password
end

class Video < ActiveRecord::Base
  belongs_to :show
  belongs_to :network
  belongs_to :episode
  
  validate :validate_episode_has_same_show_id
  
  def validate_episode_has_same_show_id
    if episode && episode.show_id != show_id
      errors.add "Video needs same show as the episode; show_id is #{show_id.inspect} while episode.show_id is #{episode.show_id.inspect}"
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

# ============================================================================
# sample_models configuration
SampleModels.configure Appointment do |appointment|
  appointment.before_save do |a|
    a.user_id = a.calendar.user_id
  end
end

SampleModels.configure BlogPost do |bp|
  bp.published_at.force_unique
  
  bp.funny_sample :title => 'Funny haha', :average_rating => 3.0
end

SampleModels.configure Category do |category|
  category.parent.default nil
end

SampleModels.configure Subscription do |sub|
  sub.subscribable.default_class BlogPost
end

SampleModels.configure Video do |video|
  video.before_save do |v, sample_attrs|
    if v.episode && v.episode.show != v.show
      if sample_attrs[:show]
        v.episode.show = v.show
      else
        v.show = v.episode.show
      end
    end
  end
  video.view_count.default 0
end

