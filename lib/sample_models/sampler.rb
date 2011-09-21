module SampleModels
  class Sampler
    def initialize(model_class)
      @model_class = model_class
      @first_pass_attribute_sequences = {}
      @second_pass_attribute_sequences = {}
    end
    
    def first_pass_attribute_sequence(column)
      unless @first_pass_attribute_sequences[column.name]
        input = FirstPassBaseAttributeSequence.new(model, column)
        model.validations(column).each do |validation|
          sequence_name = validation.type.to_s.camelize + 'AttributeSequence'
          if SampleModels.const_defined?(sequence_name)
            sequence_class = SampleModels.const_get(sequence_name)
            input = sequence_class.new(model, column, validation, input)
          end
        end
        @first_pass_attribute_sequences[column.name] = input
      end
      @first_pass_attribute_sequences[column.name]
    end
    
    def model
      SampleModels.models[@model_class]
    end
    
    def sample(*args)
      specified_attrs = HashWithIndifferentAccess.new(args.first || {})
      attrs = specified_attrs.clone
      model.columns.each do |column|
        attrs[column.name] ||= first_pass_attribute_sequence(column).next
      end
      instance = model.create!(attrs)
      instance = update_with_deferred_associations(instance, specified_attrs)
      instance
    end
    
    def second_pass_attribute_sequence(column)
      unless @second_pass_attribute_sequences[column.name]
        input = SecondPassBaseAttributeSequence.new(model, column)
        model.validations(column).each do |validation|
          sequence_name = validation.type.to_s.camelize + 'AttributeSequence'
          if SampleModels.const_defined?(sequence_name)
            sequence_class = SampleModels.const_get(sequence_name)
            input = sequence_class.new(model, column, validation, input)
          end
        end
        @second_pass_attribute_sequences[column.name] = input
      end
      @second_pass_attribute_sequences[column.name]
    end
    
    def update_with_deferred_associations(instance, specified_attrs)
      deferred_assocs = model.associations.select { |a|
        a.belongs_to? && instance.send(a.foreign_key).nil? &&
          !specified_attrs.member?(a.foreign_key) &&
          !specified_attrs.member?(a.name)
      }
      unless deferred_assocs.empty?
        deferred_assocs.each do |a|
          column = model.columns.detect { |c| c.name == a.foreign_key }
          instance.send(
            "#{a.foreign_key}=", 
            second_pass_attribute_sequence(column).next
          )
        end
        instance.save!
      end
      instance
    end
  end
end
