require 'delegate'

module SampleModels
  class Model < Delegator
    attr_reader :validation_collections
    
    def initialize(model_class)
      @model_class = model_class
      @validation_collections = Hash.new { |h, field|
        h[field] = ValidationCollection.new(self, field)
      }
    end
    
    def __getobj__
      @model_class
    end
    
    def associations(klass)
      @model_class.reflect_on_all_associations.select { |a|
        begin
          a.klass == klass
        rescue NameError
          false
        end
      }
    end
    
    def belongs_to_associations
      @model_class.reflect_on_all_associations.select { |assoc|
        assoc.macro == :belongs_to
      }
    end
    
    def construct_finder_sql(*args)
      @model_class.send(:construct_finder_sql, *args)
    end
    
    def has_many_associations
      @model_class.reflect_on_all_associations.select { |assoc|
        assoc.macro == :has_many
      }
    end
    
    def record_validation(*args)
      type = args.shift
      config = args.extract_options!
      fields = args
      fields.each do |field|
        @validation_collections[field].add(type, config)
      end
    end
    
    def validates_presence_of?(attr)
      @validation_collections[attr].includes_presence?
    end
  
    class ValidationCollection
      def initialize(model, field)
        @model, @field = model, field
        @sequence_number = 0
        @validations = {}
      end
      
      def add(type, config)
        @validations[type] = config
      end
      
      def association
        @model.belongs_to_associations.detect { |a|
          a.association_foreign_key.to_sym == @field.to_sym
        }
      end
      
      def column
        @model.columns.detect { |c| c.name == @field.to_s }
      end
      
      def includes_presence?
        @validations.has_key?(:validates_presence_of)
      end
      
      def includes_uniqueness?
        @validations.has_key?(:validates_uniqueness_of)
      end
      
      def satisfying_present_associated_value
        value = if includes_uniqueness?
          association.klass.create_sample
        else
          association.klass.first || association.klass.sample
        end
        value = value.id if value
        value
      end
      
      def satisfying_present_value(prev_value)
        if association
          satisfying_present_associated_value
        else
          if prev_value.present?
            prev_value
          elsif column && column.type == :date
            Date.today
          else
            "#{@field} #{@sequence_number}"
          end
        end
      end
      
      def satisfying_value
        @sequence_number += 1 if includes_uniqueness?
        value = nil
        @validations.each do |type, config|
          case type
          when :validates_email_format_of
            value = "john.doe#{@sequence_number}@example.com"
          when :validates_inclusion_of
            value = config[:in].first
          when :validates_presence_of
            value = satisfying_present_value(value)
          end
        end
        value = unique_value if value.nil? && includes_uniqueness?
        value
      end
      
      def unique_value
        if column.type == :string
          "#{@field.to_s.capitalize} #{@sequence_number}"
        elsif column.type == :datetime
          Time.utc(1970, 1, 1) + @sequence_number.days
        end
      end
    end
  end
end
