RAILS_ENV = 'test'
require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  exit e.status_code
end

require 'active_record'
require 'active_record/base'
require 'logger'

ActiveRecord::Base.logger = Logger.new(
  File.dirname(__FILE__) + '/../log/test.log'
)
ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3', :database => 'test/db/test.sqlite3'
)

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
    
    create_table 'calendars', :force => true do |calendar|
      calendar.integer 'user_id'
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

    create_table 'external_users', :force => true do |external_user|
    end

    create_table 'networks', :force => true do |network|
      network.string 'name'
    end
    
    create_table 'shows', :force => true do |show|
      show.integer 'network_id', 'subscription_price'
      show.string  'name'
    end

    create_table 'users', :force => true do |user|
      user.integer 'favorite_blog_post_id', 'external_user_id'
      user.string  'email', 'gender', 'homepage', 'login', 'password'
    end

    create_table 'videos', :force => true do |video|
      video.integer 'episode_id', 'show_id', 'network_id', 'view_count'
    end
  end
end

require 'validates_email_format_of'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'sample_models'

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

class ExternalUser < ActiveRecord::Base
end

class Network < ActiveRecord::Base
end

class Show < ActiveRecord::Base
  belongs_to :network
end

class User < ActiveRecord::Base
  belongs_to :favorite_blog_post,
             :class_name => 'BlogPost', :foreign_key => 'favorite_blog_post_id'
  belongs_to :external_user

  validates_email_format_of :email
  validates_inclusion_of    :gender, :in => %w(f m)
  validates_uniqueness_of   :email, :login, :case_sensitive => false
  validates_uniqueness_of   :external_user_id, :allow_nil => true
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

require 'test/unit'

