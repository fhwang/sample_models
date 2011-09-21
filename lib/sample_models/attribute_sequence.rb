module SampleModels
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
