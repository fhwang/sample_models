module SampleModels
  class Sampler
    def initialize(model_class)
      @model_class = model_class
      @attribute_sequences = {}
    end
    
    def attribute_sequence(column)
      unless @attribute_sequences[column.name]
        input = BaseAttributeSequence.new(model, column)
        model.validations(column).each do |validation|
          sequence_name = validation.type.to_s.camelize + 'AttributeSequence'
          if Sampler.const_defined?(sequence_name)
            sequence_class = Sampler.const_get(sequence_name)
            input = sequence_class.new(model, column, validation, input)
          end
        end
        @attribute_sequences[column.name] = input
      end
      @attribute_sequences[column.name]
    end
    
    def model
      SampleModels.models[@model_class]
    end
    
    def sample(*args)
      attrs = args.first || {}
      model.columns.each do |column|
        attrs[column.name] ||= attribute_sequence(column).next
      end
      model.create!(attrs)
    end
    
    class AttributeSequence
      def initialize(model, column, validation, input)
        @model, @column, @validation, @input = model, column, validation, input
        @number = 0
      end
      
      def integer_value
        assoc = @model.associations.detect { |a|
          a.belongs_to? && a.foreign_key == @column.name
        }
        assoc ? nil : @number
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
    
    class BaseAttributeSequence < AttributeSequence
      def initialize(model, column)
        super(model, column, nil, nil)
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
        v = @input.next
        unless @validation.config[:allow_nil] && v.nil?
          unless @validation.config[:allow_blank] && v.blank?
            v = @input.next until @model.unique?(@column.name, v)
          end
        end
        v
      end
    end
  end
end
