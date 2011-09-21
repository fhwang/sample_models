module SampleModels
  class Initializer
    def run
      ActiveRecord::Base.send(:include, SampleModels)
      intercept_validation_definitions
    end
  
    def intercept_validation_definition(validation, recipient)
      method_name = "#{validation}_with_sample_models".to_sym
      recipient.send(:define_method, method_name) do |*args|
        send "#{validation}_without_sample_models".to_sym, *args
        SampleModels.models[self].record_validation(validation, *args)
      end
      recipient.alias_method_chain validation, :sample_models
    end
    
    def intercept_validation_definitions
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
          intercept_validation_definition(validation, recipient)
        else
          unless optional_interceptions.include?(validation)
            raise "Can't find who defines the validation method #{validation}"
          end
        end
      end
    end
    
    def validation_recipients
      validation_recipients = [ActiveRecord::Validations::ClassMethods]
      if Object.const_defined?('ActiveModel')
        validation_recipients << ActiveModel::Validations::HelperMethods
      end
      if Object.const_defined?('ValidatesEmailFormatOf')
        validation_recipients <<  ValidatesEmailFormatOf::Validations
      end
      validation_recipients
    end
  end
end
