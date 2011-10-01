module SampleModels
  class AttributeSequence
    def self.base(pass, model, column)
      base_class = SampleModels.const_get(
        "#{pass.to_s.capitalize}PassBaseAttributeSequence"
      )
      base_class.new(model, column)
    end

    def self.build(pass, model, column, force_unique)
      input = base(pass, model, column)
      uniqueness_validation = if force_unique
        Model::Validation.new(:validates_uniqueness_of)
      end
      model.validations(column.name).each do |validation|
        if validation.type == :validates_uniqueness_of
          uniqueness_validation = validation
        elsif s_class = sequence_class(validation)
          input = s_class.new(model, column, validation, input)
        end
      end
      if uniqueness_validation
        input = ValidatesUniquenessOfAttributeSequence.new(
          model, column, uniqueness_validation, input
        )
      end
      input
    end
    
    def self.sequence_class(validation)
      sequence_name = validation.type.to_s.camelize + 'AttributeSequence'
      if SampleModels.const_defined?(sequence_name)
        SampleModels.const_get(sequence_name)
      end
    end
    
    def initialize(model, column, validation, input)
      @model, @column, @validation, @input = model, column, validation, input
      @number = 0
    end
    
    def belongs_to_association
      @model.belongs_to_associations.detect { |a|
        a.foreign_key == @column.name
      }
    end
    
    def next
      @number += 1
      @input.next if @input
      value
    end
    
    def value
      case @column.type
        when :string
          "#{@column.name} #{@number}"
        when :integer
          belongs_to_association ? belongs_to_assoc_foreign_key_value : @number
        when :datetime
          Time.utc(1970, 1, 1) + @number.days
        when :date
          Date.today + @number
        when :float
          @number.to_f
        end
    end
  end
  
  class FirstPassBaseAttributeSequence < AttributeSequence
    def initialize(model, column)
      super(model, column, nil, nil)
    end
    
    def belongs_to_assoc_foreign_key_value
      nil
    end
  end
  
  class SecondPassBaseAttributeSequence < AttributeSequence
    def initialize(model, column)
      super(model, column, nil, nil)
      @previous_values = {}
    end
    
    def belongs_to_assoc_foreign_key_value
      assoc_klass = belongs_to_association.klass
      unless assoc_klass == @model.ar_class
        record = (assoc_klass.last || assoc_klass.sample)
        already_used = @previous_values.any? { |prev_num, prev_record|
          prev_record == record && prev_num != @number
        }
        while already_used
          record = assoc_klass.sample
          already_used = @previous_values.any? { |prev_num, prev_record|
            prev_record == record && prev_num != @number
          }
        end
        @previous_values[@number] = record
        record.id
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
    def belongs_to_value
      @previous_belongs_to_values ||= {}
      if @previous_belongs_to_values[@number]
        @previous_belongs_to_values[@number].id
      else
        instance = existing_instance_not_previously_returned
        instance ||= belongs_to_association.klass.sample
        @previous_belongs_to_values[@number] = instance
        instance.id
      end
    end
    
    def existing_instance_not_previously_returned
      previous_ids = @previous_belongs_to_values.values.map(&:id)
      instance = nil
      if previous_ids.empty?
        belongs_to_association.klass.last
      else
        belongs_to_association.klass.last(
          :conditions => ["id not in (?)", previous_ids]
        )
      end
    end
    
    def value
      belongs_to_association ? belongs_to_value : super
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
