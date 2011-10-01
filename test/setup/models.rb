
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

class ExternalUser < ActiveRecord::Base
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
  belongs_to :external_user

  validates_email_format_of :email
  validates_inclusion_of    :gender, :in => %w(f m)
  validates_uniqueness_of   :email, :login, :case_sensitive => false
  validates_uniqueness_of   :external_user_id, :allow_nil => true
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
      msg = "Video needs same show as the episode; show_id is #{show_id.inspect} while episode.show_id is #{episode.show_id.inspect}"
      if errors.respond_to?(:add_to_base)
        errors.add_to_base(msg)
      else
        errors[:base] << msg
      end
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
     
SampleModels.configure(Appointment) do |appointment|
  appointment.before_save do |a|
    a.user_id = a.calendar.user_id
  end
end

SampleModels.configure(BlogPost) do |bp|
  bp.published_at.force_unique
  
  bp.funny_sample :title => 'Funny haha', :average_rating => 3.0
end

SampleModels.configure(Category) do |category|
  category.parent.default nil
end

SampleModels.configure(Subscription) do |sub|
  sub.subscribable.default_class BlogPost
end

SampleModels.configure(Video) do |video|
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

