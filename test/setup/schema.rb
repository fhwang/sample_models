require 'active_record'
require 'active_record/base'
require 'logger'

ActiveRecord::Base.logger = Logger.new(
  File.dirname(__FILE__) + '/../../log/test.log'
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
      blog_post.text    'body'
      blog_post.timestamps
    end
    
    create_table "blog_post_tags", :force => true do |t|
      t.integer "blog_post_id"
      t.integer "tag_id"
    end
    
    create_table "bookmarks", :force => true do |t|
      t.integer "bookmarkable_id"
      t.string  "bookmarkable_type"
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
    
    create_table 'subscriptions', :force => true do |subscription|
      subscription.integer 'subscribable_id', 'user_id'
      subscription.string  'subscribable_type'
    end

    create_table "tags", :force => true do |t|
      t.string  "tag"
    end

    create_table 'topics', :force => true do |t|
      t.string  'name'
      t.integer 'parent_id'
      t.boolean 'root', :default => false
    end

    create_table 'users', :force => true do |user|
      user.integer 'favorite_blog_post_id', 'external_user_id'
      user.string  'email', 'gender', 'homepage', 'login', 'password'
    end

    create_table 'user2s', :force => true do |user2|
      user2.string  'login'
      user2.string  'email'
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
