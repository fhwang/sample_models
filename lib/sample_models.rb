module SampleModels
  mattr_reader :models
  @@models = Hash.new { |h, model_class| 
    h[model_class] = Model.new(model_class)
  }
  
  mattr_reader :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(model_class)
  }
  
  def self.init
    ActiveRecord::Base.send(:include, SampleModels)
    intercept_validation_definitions
  end
  
  protected
  
  def self.included(mod)
    mod.extend ARClassMethods
    super
  end
  
  def self.intercept_validation_definitions
    validation_recipients = [ActiveRecord::Validations::ClassMethods]
    if Object.const_defined?('ActiveModel')
      validation_recipients << ActiveModel::Validations::HelperMethods
    end
    validations_to_intercept = [
      :validates_email_format_of, :validates_inclusion_of,
      :validates_presence_of, :validates_uniqueness_of
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
  end

  module ARClassMethods
    def sample(*args)
      SampleModels.samplers[self].sample(*args)
    end
  end
end

Dir.entries(File.dirname(__FILE__) + "/sample_models").each do |entry|
  if entry =~ /(.*)\.rb/
    require "sample_models/#{$1}"
  end
end

SampleModels.init

