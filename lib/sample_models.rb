module SampleModels
  mattr_reader :models
  @@models = Hash.new { |h, model_class| 
    h[model_class] = Model.new(model_class)
  }
  
  mattr_reader :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(model_class)
  }
  
  protected
  
  def self.included(mod)
    mod.extend ARClassMethods
    super
  end

  module ARClassMethods
    def sample(*args)
      SampleModels.samplers[self].sample(*args)
    end
  end
  
  class Model
    attr_reader :validations_by_attr
    
    def initialize(model_class)
      @model_class = model_class
      @validations_by_attr = Hash.new { |h,k| h[k] = [] }
    end
    
    def associations
      @model_class.reflect_on_all_associations.map { |a| Association.new(a) }
    end
    
    def record_validation(*args)
      type = args.shift
      config = args.extract_options!
      fields = args
      fields.each do |field|
        @validations_by_attr[field] << [type, config]
      end
    end
    
    require 'delegate'
    
    class Association < Delegator
      def initialize(assoc)
        @assoc = assoc
      end
      
      def __getobj__
        @assoc
      end
      
      def belongs_to?
        @assoc.macro == :belongs_to
      end
      
      def foreign_key
        if @assoc.respond_to?(:foreign_key)
          @assoc.foreign_key
        else
          @assoc.primary_key_name
        end
      end
    end
  end
  
  class Sampler
    def initialize(model_class)
      @model_class = model_class
    end
    
    def attribute_for_creation(column)
      validations = model.validations_by_attr[column.name.to_sym]
      if validations.any? { |validation|
          validation.first == :validates_email_format_of
      }
        "john.doe@example.com"
      elsif validation = validations.detect { |validation|
          validation.first == :validates_inclusion_of
      }
        validation.last[:in].first
      else
        case column.type
          when :string
            "string"
          when :integer
            assoc = model.associations.detect { |a|
              a.belongs_to? && a.foreign_key == column.name
            }
            if assoc
              if validations.detect { |v| v.first == :validates_presence_of }
                record = assoc.klass.last
                record ||= assoc.klass.sample
                record.id
              else
                nil
              end
            else
              1
            end
          when :datetime
            Time.now.utc
          when :float
            1.0
          end
      end
    end
    
    def model
      SampleModels.models[@model_class]
    end
    
    def sample(*args)
      attrs = {}
      @model_class.columns.each do |column|
        attrs[column.name] = attribute_for_creation(column)
      end
      @model_class.create!(attrs)
    end
  end
end

ActiveRecord::Base.send(:include, SampleModels)

validation_recipients = [ActiveRecord::Validations::ClassMethods]
if Object.const_defined?('ActiveModel')
  validation_recipients << ActiveModel::Validations::HelperMethods
end
validations_to_intercept = [
  :validates_email_format_of, :validates_inclusion_of, :validates_presence_of, 
  :validates_uniqueness_of
]
optional_interceptions = [:validates_email_format_of]
validations_to_intercept.each do |validation|
  recipient = validation_recipients.detect { |vr|
    vr.method_defined?(validation)
  }
  if recipient
    method_name = "#{validation}_with_sample_models".to_sym
    recipient.send(:define_method, method_name) do |*args|
      send "#{validation}_without_sample_models".to_sym, *args
      SampleModels.models[self].record_validation(validation, *args)
    end
    recipient.alias_method_chain validation, :sample_models
  else
    unless optional_interceptions.include?(validation)
      raise "Can't find who defines the validation method #{validation}"
    end
  end
end
