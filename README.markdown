SampleModels
============

A library for making it extremely fast for Rails developers to set up and save ActiveRecord instances when writing test cases. It aims to:

* meet all your validations automatically
* only make you specify the attributes you care about
* give you a rich set of features so you can specify associated values as concisely as possible
* do this with as little configuration as possible

Feature overview
================

Let's say you've got a set of models that look like this:

    class BlogPost < ActiveRecord::Base
      has_many   :blog_post_tags
      has_many   :tags, :through => :blog_post_tags
      belongs_to :user
      
      validates_presence_of :title, :user_id
    end

    class BlogPostTag < ActiveRecord::Base
      belongs_to :blog_post
      belongs_to :tag
    end

    class Tag < ActiveRecord::Base
      validates_uniqueness_of :tag
      
      has_many :blog_post_tags
      has_many :blog_posts, :through => :blog_post_tags
    end 

    class User < ActiveRecord::Base
      has_many :blog_posts
    
      validates_email_format_of :email
      validates_inclusion_of    :gender, :in => %w(f m)
      validates_uniqueness_of   :email, :login
    end

You can get a valid instance of a BlogPost by calling BlogPost.sample in a test environment:

    blog_post1 = BlogPost.sample
    puts blog_post1.title            # => some non-empty string
    puts blog_post1.user.is_a?(User) # => true

SampleModels does this without any configuration at all. It does this by reading your class definition to figure out validations and associations for you.

If you care about specific fields, you can specify them like so:

    blog_post2 = BlogPost.sample :title => 'What I ate for lunch'
    puts blog_post2.title            # => 'What I ate for lunch'
    puts blog_post2.user.is_a?(User) # => true

Often calls to `sample` will return the same record. If you want to 
    
    BlogPost.sample
    BlogPost.create_sample
    User.sample
      # gender will be either f or m, email will be an email address
    
    BlogPost.sample :user => {:email => 'john@example.com'}

    foodie = User.sample :email => 'food-blogger@example.com'
    BlogPost.sample(foodie, :title => 'What I ate for lunch')
    
    BlogPost.sample :tags => [{:tag => 'funny'}, {:tag => 'sad'}]


    
    
Setting associations
====================



Hooks
=====


Copyright (c) 2010 Francis Hwang, released under the MIT license
