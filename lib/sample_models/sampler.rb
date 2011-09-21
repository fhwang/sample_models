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
      Creation.new(self, *args).run
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
  end
end
