module SampleModels
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
            integer_attribute_for_creation(column)
          when :datetime
            Time.now.utc
          when :float
            1.0
          end
      end
    end
    
    def integer_attribute_for_creation(column)
      validations = model.validations_by_attr[column.name.to_sym]
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
