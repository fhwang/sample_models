if RAILS_ENV == 'test' # no reason to run this code outside of test mode
  
require 'delegate'
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
      Attribute.new(sampler, meth)
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
    def create_sample(attrs={})
      SampleModels.samplers[self].create_sample attrs
    end
    
    def sample(attrs={})
      SampleModels.samplers[self].sample attrs
    end
  end
  
  class Model < Delegator
    attr_reader :validation_collections
    
    def initialize(model_class)
      @model_class = model_class
      @validation_collections = Hash.new { |h, field|
        h[field] = ValidationCollection.new(self, field)
      }
    end
    
    def __getobj__
      @model_class
    end
    
    def belongs_to_associations
      @model_class.reflect_on_all_associations.select { |assoc|
        assoc.macro == :belongs_to
      }
    end
    
    def has_many_associations
      @model_class.reflect_on_all_associations.select { |assoc|
        assoc.macro == :has_many
      }
    end
    
    def record_validation(*args)
      type = args.shift
      config = args.extract_options!
      fields = args
      fields.each do |field|
        @validation_collections[field].add(type, config)
      end
    end
    
    def validates_presence_of?(attr)
      @validation_collections[attr].includes_presence?
    end
  end
  
  class ValidationCollection
    def initialize(model, field)
      @model, @field = model, field
      @sequence_number = 0
      @validations = {}
    end
    
    def add(type, config)
      @validations[type] = config
    end
    
    def column
      @model.columns.detect { |c| c.name == @field.to_s }
    end
    
    def includes_presence?
      @validations.has_key?(:validates_presence_of)
    end
    
    def includes_uniqueness?
      @validations.has_key?(:validates_uniqueness_of)
    end
    
    def satisfying_value
      @sequence_number += 1 if includes_uniqueness?
      value = nil
      @validations.each do |type, config|
        case type
        when :validates_email_format_of
          value = "john.doe#{@sequence_number}@example.com"
        when :validates_inclusion_of
          value = config[:in].first
        when :validates_presence_of
          assoc = @model.belongs_to_associations.detect { |a|
            a.association_foreign_key.to_sym == @field.to_sym
          }
          if assoc
            value = if includes_uniqueness?
              assoc.klass.create_sample
            else
              assoc.klass.first || assoc.klass.sample
            end
            value = value.id if value
          else
            value ||= "#{@field} #{@sequence_number}"
          end
        end
      end
      if value.nil? && includes_uniqueness?
        value = if column.type == :string
          "#{@field.to_s.capitalize} #{@sequence_number}"
        elsif column.type == :datetime
          Time.utc(1970, 1, 1) + @sequence_number.days
        end
      end
      value
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

