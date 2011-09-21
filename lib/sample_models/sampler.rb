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
          if Sampler.const_defined?(sequence_name)
            sequence_class = Sampler.const_get(sequence_name)
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
      deferred_assocs = model.associations.select { |a|
        a.belongs_to? && attrs[a.foreign_key].nil? &&
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
    
    def second_pass_attribute_sequence(column)
      unless @second_pass_attribute_sequences[column.name]
        input = SecondPassBaseAttributeSequence.new(model, column)
        model.validations(column).each do |validation|
          sequence_name = validation.type.to_s.camelize + 'AttributeSequence'
          if Sampler.const_defined?(sequence_name)
            sequence_class = Sampler.const_get(sequence_name)
            input = sequence_class.new(model, column, validation, input)
          end
        end
        @second_pass_attribute_sequences[column.name] = input
      end
      @second_pass_attribute_sequences[column.name]
    end
    
    class AttributeSequence
      def initialize(model, column, validation, input)
        @model, @column, @validation, @input = model, column, validation, input
        @number = 0
      end
      
      def next
        @number += 1
        value
      end
      
      def value
        case @column.type
          when :string
            "#{@column.name} #{@number}"
          when :integer
            integer_value
          when :datetime
            Time.utc(1970, 1, 1) + @number.days
          when :float
            @number.to_f
          end
      end
    end
    
    class FirstPassBaseAttributeSequence < AttributeSequence
      def initialize(model, column)
        super(model, column, nil, nil)
      end
      
      def integer_value
        assoc = @model.associations.detect { |a|
          a.belongs_to? && a.foreign_key == @column.name
        }
        assoc ? nil : @number
      end
    end
    
    class SecondPassBaseAttributeSequence < AttributeSequence
      def initialize(model, column)
        super(model, column, nil, nil)
        @previous_values = {}
      end
      
      def integer_value
        assoc = @model.associations.detect { |a|
          a.belongs_to? && a.foreign_key == @column.name
        }
        if assoc
          record = (assoc.klass.last || assoc.klass.sample)
          already_used = @previous_values.any? { |prev_num, prev_record|
            prev_record == record && prev_num != @number
          }
          while already_used
            record = assoc.klass.sample
            already_used = @previous_values.any? { |prev_num, prev_record|
              prev_record == record && prev_num != @number
            }
          end
          @previous_values[@number] = record
          record.id
        else
          @number
        end
      end
    end
    
    class ValidatesEmailFormatOfAttributeSequence < AttributeSequence
      def value
        "john.doe.#{@number}@example.com"
      end
    end
    
    class ValidatesInclusionOfAttributeSequence < AttributeSequence
      def value
        @validation.config[:in].first
      end
    end
    
    class ValidatesPresenceOfAttributeSequence < AttributeSequence
      def value
        if assoc = @model.associations.detect { |a|
          a.belongs_to? && a.foreign_key == @column.name
        }
          (assoc.klass.last || assoc.klass.sample).id
        else
          super
        end
      end
    end
    
    class ValidatesUniquenessOfAttributeSequence < AttributeSequence
      def value
        v = @input.value
        unless @validation.config[:allow_nil] && v.nil?
          unless @validation.config[:allow_blank] && v.blank?
            until @model.unique?(@column.name, v)
              v = @input.next
            end
          end
        end
        v
      end
    end
  end
end
