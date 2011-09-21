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
      attrs = HashWithIndifferentAccess.new(
        args.last.is_a?(Hash) ? args.pop : {}
      )
      args.each do |associated_value|
        assocs = model.associations.select { |a|
          begin
            a.klass == associated_value.class
          rescue NameError
            false
          end
        }
        if assocs.size == 1
          attrs[assocs.first.name] = associated_value
        else
          raise "Not sure what to do with associated value #{associated_value.inspect}"
        end
      end
      model.belongs_to_associations.each do |assoc|
        if value = attrs[assoc.name]
          if value.is_a?(Hash)
            attrs[assoc.name] = assoc.klass.sample(value)
          elsif value.is_a?(Array)
            attrs[assoc.name] = assoc.klass.sample(*value)
          end
        end
      end
      Creation.new(self, attrs).run
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
    
    class Creation
      def initialize(sampler, specified_attrs)
        @sampler, @specified_attrs = sampler, specified_attrs
      end
      
      def model
        @sampler.model
      end
      
      def run
        attrs = @specified_attrs.clone
        model.columns.each do |column|
          sequence = @sampler.first_pass_attribute_sequence(column)
          attrs[column.name] ||= sequence.next
        end
        @instance = model.create!(attrs)
        update_with_deferred_associations
        @instance
      end
    
      def update_with_deferred_associations
        deferred_assocs = model.belongs_to_associations.select { |a|
          @instance.send(a.foreign_key).nil? &&
            !@specified_attrs.member?(a.foreign_key) &&
            !@specified_attrs.member?(a.name)
        }
        unless deferred_assocs.empty?
          deferred_assocs.each do |a|
            column = model.columns.detect { |c| c.name == a.foreign_key }
            @instance.send(
              "#{a.foreign_key}=", 
              @sampler.second_pass_attribute_sequence(column).next
            )
          end
          @instance.save!
        end
      end
    end
  end
end
