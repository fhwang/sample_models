if RAILS_ENV == 'test' # no reason to run this code outside of test mode
  
require "#{File.dirname(__FILE__)}/sample_models/sampler"
require "#{File.dirname(__FILE__)}/../vendor/ar_query/lib/ar_query"

module SampleModels
  mattr_reader   :samplers
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
        @sampler.configured_default_attrs[@attribute] = default
      end
      
      def force_unique
        @sampler.record_validation :validates_uniqueness_of, @attribute
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
  
  class Model
    def self.belongs_to_associations(model)
      model.reflect_on_all_associations.select { |assoc|
        assoc.macro == :belongs_to
      }
    end
    
    def self.has_many_associations(model)
      model.reflect_on_all_associations.select { |assoc|
        assoc.macro == :has_many
      }
    end
  end
  
  class ValidationCollection
    def initialize(model_class, field)
      @model_class, @field = model_class, field
      @sequence_number = 0
      @validations = {}
    end
    
    def add(type, config)
      @validations[type] = config
    end
    
    def column
      @model_class.columns.detect { |c| c.name == @field.to_s }
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
          assoc = Model.belongs_to_associations(@model_class).detect { |a|
            a.association_foreign_key.to_sym == @field.to_sym
          }
          value = if assoc
            if includes_uniqueness?
              assoc.klass.create_sample
            else
              assoc.klass.first || assoc.klass.sample
            end
          end
          value = value.id if value
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
            SampleModels.samplers[self].record_validation(
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

