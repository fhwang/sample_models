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

def initialize_db
  silence_stream(STDOUT) do
    ActiveRecord::Schema.define do
      create_table 'appointments', :force => true do |appointment|
        appointment.datetime 'time'
      end
    
      create_table 'blog_posts', :force => true do |blog_post|
        blog_post.datetime 'published_at'
        blog_post.integer 'merged_into_id', 'user_id'
        blog_post.string  'title'
      end
    
      create_table "blog_post_tags", :force => true do |t|
        t.integer "blog_post_id"
        t.integer "tag_id"
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
      end
      
      create_table 'networks', :force => true do |network|
        network.string 'name'
      end
      
      create_table 'shows', :force => true do |show|
        show.integer 'network_id'
        show.string  'name'
      end

      create_table "tags", :force => true do |t|
        t.string  "tag"
      end

      create_table 'users', :force => true do |user|
        user.integer 'favorite_blog_post_id'
        user.string  'email', 'gender', 'homepage', 'login', 'password'
      end
      
      create_table 'videos', :force => true do |video|
        video.integer 'episode_id', 'show_id', 'network_id'
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
  validates_uniqueness_of :time
end

class Category < ActiveRecord::Base
  belongs_to :parent, :class_name => 'Category'
end

class Comment < ActiveRecord::Base
end

class BlogPost < ActiveRecord::Base
  has_many   :blog_post_tags
  belongs_to :merged_into,
             :class_name => 'BlogPost', :foreign_key => 'merged_into_id'
  has_many   :tags, :through => :blog_post_tags
  belongs_to :user
  
  validates_presence_of :user_id
end

class BlogPostTag < ActiveRecord::Base
  belongs_to :blog_post
  belongs_to :tag
end

class Episode < ActiveRecord::Base
  belongs_to :show
  
  validates_presence_of :show_id
end

class Network < ActiveRecord::Base
end

class Show < ActiveRecord::Base
  belongs_to :network
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

class Video < ActiveRecord::Base
  belongs_to :show
  belongs_to :network
  belongs_to :episode
  
  def validate
    if episode && episode.show_id != show_id
      errors.add "Video needs same show as the episode"
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
SampleModels.configure BlogPost do |bp|
  bp.published_at.force_unique
end

SampleModels.configure Category do |category|
  category.parent.default nil
end

SampleModels.configure Video do |video|
  video.before_save { |v, sample_attrs|
    if v.episode && v.episode.show != v.show
      if sample_attrs[:show]
        v.episode.show = v.show
      else
        v.show = v.episode.show
      end
    end
  }
end
