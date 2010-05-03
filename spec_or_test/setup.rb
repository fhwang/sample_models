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
        blog_post.integer 'merged_into_id', 'user_id'
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
      
      create_table 'users', :force => true do |user|
        user.integer 'favorite_blog_post_id'
        user.string  'email', 'gender', 'homepage', 'login', 'password'
      end
      
      create_table 'videos', :force => true do |video|
        video.integer 'episode_id', 'show_id', 'network_id'
      end
    end
  end
end

# ============================================================================
# Define ActiveRecord classes
class Appointment < ActiveRecord::Base
  validates_uniqueness_of :time
end

class Comment < ActiveRecord::Base
end

class BlogPost < ActiveRecord::Base
  belongs_to :merged_into,
             :class_name => 'BlogPost', :foreign_key => 'merged_into_id'
  belongs_to :user
  
  validates_presence_of :user_id
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

class User < ActiveRecord::Base
  belongs_to :favorite_blog_post,
             :class_name => 'BlogPost', :foreign_key => 'favorite_blog_post_id'
             
  validates_email_format_of :email
  validates_inclusion_of    :gender, :in => %w(f m)
  validates_uniqueness_of   :email, :login, :case_sensitive => false
end

# ============================================================================
# sample_models configuration
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