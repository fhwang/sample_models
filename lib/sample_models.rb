if RAILS_ENV == 'test' # no reason to run this code outside of test mode
  
require "#{File.dirname(__FILE__)}/sample_models/creation"
require "#{File.dirname(__FILE__)}/sample_models/model"
require "#{File.dirname(__FILE__)}/sample_models/sampler"
require "#{File.dirname(__FILE__)}/../vendor/ar_query/lib/ar_query"

module SampleModels
  mattr_reader :models
  @@models = Hash.new { |h, model_class| 
    h[model_class] = Model.new(model_class)
  }
  
  mattr_reader :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(model_class)
  }

  def self.configure(model_class, opts ={})
    yield ConfigureRecipient.new(model_class) if block_given?
  end

  protected
  
  def self.included( mod )
    mod.extend ARClassMethods
    super
  end
  
  class ConfigureRecipient
    def initialize(model_class)
      @model_class = model_class
    end
    
    def before_save(&proc)
      sampler.before_save = proc
    end
    
    def method_missing(meth, *args)
      if meth.to_s =~ /(.*)_sample$/
        sampler.named_sample_attrs[$1] = args.first
      else
        Attribute.new(sampler, meth)
      end
    end
    
    def sampler
      SampleModels.samplers[@model_class]
    end
    
    class Attribute
      def initialize(sampler, attribute)
        @sampler, @attribute = sampler, attribute
      end
      
      def default(default)
        if default.blank? and model.validates_presence_of?(@attribute)
          raise "#{model.name} requires #{@attribute} to not be blank"
        else
          @sampler.configured_default_attrs[@attribute] = default
        end
      end
      
      def force_unique
        model.record_validation :validates_uniqueness_of, @attribute
      end
      
      def model
        SampleModels.models[@sampler.model_class]
      end
    end
  end
  
  module ARClassMethods
    def create_sample(*args)
      sampler = SampleModels.samplers[self]
      sampler.create_sample(sampler.attrs_from_args(*args))
    end
    
    def sample(*args)
      sampler = SampleModels.samplers[self]
      sampler.sample(sampler.attrs_from_args(*args))
    end
  end
end

module ActiveRecord
  class Base
    include SampleModels
  end
  
  module Validations
    module ClassMethods
      [:validates_email_format_of,
       :validates_inclusion_of, :validates_presence_of, 
       :validates_uniqueness_of].each do |validation|
        if method_defined?(validation)
          define_method "#{validation}_with_sample_models".to_sym do |*args|
            send "#{validation}_without_sample_models".to_sym, *args
            SampleModels.models[self].record_validation(
              validation, *args
            )
          end
          alias_method_chain validation, :sample_models
        end
      end
    end
  end
end

end # if RAILS_ENV == 'test'

