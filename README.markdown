SampleModels
============

A library for making it extremely fast for Rails developers to set up and save ActiveRecord instances when writing test cases. It aims to:

* meet all your validations automatically
* only make you specify the attributes you care about
* give you a rich set of features so you can specify associations as concisely as possible
* do this with as little configuration as possible

Overview
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
    
      validates_inclusion_of    :gender, :in => %w(f m)
      validates_uniqueness_of   :email, :login
      # from http://github.com/alexdunae/validates_email_format_of
      validates_email_format_of :email
    end

You can get a valid instance of a BlogPost by calling BlogPost.sample in a test environment:

    blog_post1 = BlogPost.sample
    puts blog_post1.title             # => some non-empty string
    puts blog_post1.user.is_a?(User)  # => true

    user1 = User.sample
    puts user1.email                  # => will be a valid email 
    puts user1.gender                 # => will be either 'f' or 'm'

Since SampleModels figures out validations and associations from your ActiveRecord class definitions, it can usually fill in the required values without any configuration at all.
    
If you care about specific fields, you can specify them like so:

    blog_post2 = BlogPost.sample(:title => 'What I ate for lunch')
    puts blog_post2.title             # => 'What I ate for lunch'
    puts blog_post2.user.is_a?(User)  # => true

You can specify associated records in the sample call:

    bill = User.sample(:first_name => 'Bill')
    bills_post = BlogPost.sample(:user => bill)
    
    funny = Tag.sample(:tag => 'funny')
    sad = Tag.sample(:tag => 'sad')
    funny_yet_sad = BlogPost.sample(:tags => [funny, sad])
    
You can also specify associated records by passing them in at the beginning of the argument list, if there's only one association that would work with the record's class:

    jane = User.sample(:first_name => 'Jane')
    BlogPost.sample(jane, :title => 'What I ate for lunch')
    
You can also specify associated records by passing in hashes or arrays:

    bills_post2 = BlogPost.sample(:user => {:first_name => 'Bill'})
    puts bills_post2.user.first_name  # => 'Bill'
    
    funny_yet_sad2 = BlogPost.sample(
      :tags => [{:tag => 'funny'}, {:tag => 'sad'}]
    )
    puts funny_yet_sad2.tags.size     # => 2

Instance attributes
=========================

By default, SampleModels sets each attribute on a record to a non-blank value that matches the database type. They'll often be nonsensical values like "first_name 5", but the assumption is that if you didn't specify a value, you don't really care what it is as long as it validates. Non-trivial codebases routinely end up having models with many attributes, and when you find yourself writing a test with that model, you may only care about one or two attributes in that test case. SampleModels aims to let you specify only those important attributes while letting SampleModels take care of everything else.

SampleModels reads your validations to get hints about how to craft an instance that will be valid. The current supported validations are:

validates_email_format_of
-------------------------

If you use the [validates_email_format_of gem](http://rubygems.org/gems/validates_email_format_of), SampleModels will ensure that the attribute in question is a valid email address.

validates_presence_of
---------------------

SampleModels already sets database columns to be non-blank, but this validation comes in handy if you have an `attr_accessor`:

    class UserWithPassword < ActiveRecord::Base
      attr_accessor :password
      
      validates_presence_of :password
    end
    
    user_with_password = UserWithPassword.sample
    puts user_with_password.password  # => Some non-blank string


validates_inclusion_of
----------------------

SampleModels will set the attribute to one of the specified values.


validates_length_of
-------------------

SampleModels will set the attribute to a string within the specified
length constraints.


validates_uniqueness_of
-----------------------

SampleModels will ensure that new instances will have different values for attributes where uniqueness is required, as discussed below under "New records vs. old records."


Associations
============

If your application has an extensive data model, setting up associations for a test case can be an extremely tedious endeavor. SampleModels aims to make this process easy on the programmer and easy on the reader with a number of features.

Belongs-to associations
-----------------------
As demonstrated above, belongs_to associations are automatically set like any other attribute:

    blog_post = BlogPost.sample
    puts blog_post.user.is_a?(User)   # => true
    
You can also specify these associations as if you were calling `new` or `create!`:

    kelley = User.sample(:first_name => 'Kelley')
    BlogPost.sample(:user => kelley)
    BlogPost.sample(:user_id => kelley.id)

If you want, you can simply specify the record at the beginning of the argument list for `sample`, and SampleModels will assign them to the appropriate association, as long as there's only one association that fits the class.

    kim = User.sample(:first_name => 'Kim')
    BlogPost.sample(kim, :title => 'funny')
   
You can do this with multiple belongs-to associations:
    
    class Network < ActiveRecord::Base
    end
    
    class Show < ActiveRecord::Base
      belongs_to :network
    end
        
    class Video < ActiveRecord::Base
      belongs_to :show
      belongs_to :network
    end
    
    amc = Network.sample(:name => 'AMC')
    mad_men = Show.sample(:name => 'Mad Men')
    video = Video.sample(amc, mad_men, :name => 'The Suitcase')
    
If you want, you can simply specify the important attributes of the associated value, and SampleModels will stitch it all together for you:

    blog_post = BlogPost.sample(:user => {:first_name => 'Bill'})
    puts blog_post.user.first_name  # => 'Bill'

You can combine the two syntaxes in deeper associations:

    bb_episode = Video.sample(:show => [amc, {:name => 'Breaking Bad'}])
    puts bb_episode.show.network.name   # => 'AMC'
    puts bb_episode.show.name           # => 'Breaking Bad'

Polymorphic belongs-to associations
-----------------------------------

In the case of a polymorphic belongs-to association, SampleModels will attach any record it can find, of any model class.

    class Bookmark < ActiveRecord::Base
      belongs_to :bookmarkable, :polymorphic => true
    end
    
    bookmark = Bookmark.sample
    puts bookmark.bookmarkable.class  # could be any model class
    
Of course, you can specify the polymorphic association yourself if that's important to the test.

    blog_post = BlogPost.sample(:title => 'Read me later')
    Bookmark.sample(:bookmarkable => blog_post)
    
You can also configure the default class of this polymorphic association with `default_class`, explained below under "Configuration".    

Has-many associations
---------------------

You can set a has-many association with an array of instances, as you'd do with `new` or `create!`:

    funny = Tag.sample(:tag => 'funny')
    sad = Tag.sample(:tag => 'sad')
    funny_yet_sad1 = BlogPost.sample(:tags => [funny, sad])
    
You can also pass hashes to specify the records:

    funny_yet_sad2 = BlogPost.sample(
      :tags => [{:tag => 'funny'}, {:tag => 'sad'}]
    )
    
Or you can combine the two if that's more convenient:
    
    funny_yet_sad3 = BlogPost.sample(:tags => [{:tag => 'sad'}, funny])

Configuration
=============

The aim of SampleModels is to require as little configuration as possible -- you'll typically find that most of your models won't need any configuration at all. However, there are a few hooks for when you're trying to accommodate advanced creational behavior.

before_save
-----------

With `before_save` you can specify a block that runs before the record is saved. For example, let's say you've got Users, Appointments, and Calendars, and an Appointment should have the same User as the Calendar it belongs to. You can set this behavior with `before_save`:

    # app/models/appointment.rb
    class Appointment < ActiveRecord::Base
      belongs_to :calendar
      belongs_to :user
      
      def validate
        if user_id != calendar.user_id
          errors.add_to_base("Calendar has a different user than me")
        end
      end
    end
    
    # app/models/calendar.rb
    class Calendar < ActiveRecord::Base
      has_many    :appointments
      belongs_to  :user
    end
    
    # test/test_helper.rb
    SampleModels.configure(Appointment) do |appt|
      appt.before_save do |appt_record|
        appt_record.user_id = appt_record.calendar.user_id
      end
    end

You can also take a second argument, which will pass in the hash that was used during the call to `sample`.

    SampleModels.configure(Appointment) do |appt|
      appt.before_save do |appt_record, sample_attrs|
        unless sample_attrs.has_key?(:user) or sample_attrs.has_key?(:user_id)
          appt_record.user_id = appt_record.calendar.user_id
        end
      end
    end

default
-------
`default` will set default values for the field in question.

    SampleModels.configure(Category) do |category|
      category.parent.default nil
    end

    SampleModels.configure(Video) do |video|
      video.view_count.default 0
    end
    
A word to the wise: Be sparing with these global defaults. It's easy to tell yourself "Oh, this should be the default value everywhere" -- and then a day later find yourself wanting to override the default all over the place. In many cases you many want to used named samples (see below) instead.

default_class
-------------
By default, SampleModels fills polymorphic associations with any record, chosen practically at random. You may want to specify this to a more sensible default:

    SampleModels.configure(Bookmark) do |bookmark|
      bookmark.bookmarkable.default_class BlogPost
    end

force_email_format
------------------

Use `force_email_format` if you want to ensure that for every newly
created instance, the field will be a valid email. This has the same
effect as `validates_email_format_of`, but won't change the behavior of
production code.

    SampleModels.configure(User) do |user|
      user.email.force_email_format
    end

force_unique
------------
Use `force_unique` if you want to ensure that for every newly created instance, the field will be unique. This has the same effect as `validates_uniqueness_of`, but won't change how production code behaves.

    SampleModels.configure(BlogPost) do |bp|
      bp.published_at.force_unique
    end


Named samples
=============
Named samples can be used to pre-set values for commonly used combinations of attributes.

    SampleModels.configure(BlogPost) do |bp|
      bp.funny_sample :title => 'Laugh already', :average_rating => 3.0
      bp.sad_sample :title => 'Boo hoo', :average_rating => 2.0
    end
    
    bp1 = BlogPost.sample(:funny)
    puts bp1.title   # => 'Laugh already'

    bp2 = BlogPost.sample(:funny)
    puts bp2.title      # => 'Laugh already'
    puts (bp1 == bp2)   # => false
    
You can override individual attributes, as well:

    bp3 = BlogPost.sample(:funny, :average_rating => 4.0)
    puts bp3.average_rating   # => 4.0
    
Backwards-incompatible changes in SampleModels 2
================================================

`sample` always creates a new record now. This is a change from SampleModels 1, which would first attempt to find an existing record in the database that satisfied the stated attributes. In practice, that ended up making tests too confusing.

`create_sample` and `sample` now do the same thing, and `create_sample` is deprecated.


About
=====

Copyright (c) 2010 Francis Hwang, released under the MIT license.
