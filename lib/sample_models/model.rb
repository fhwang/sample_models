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
      if @model_class.method(:scoped).arity == -1
        @model_class.scoped.apply_finder_options(*args).arel.to_sql
      else
        @model_class.send(:construct_finder_sql, *args)
      end
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
    
    def unique?(field, value)
      !@model_class.first(:conditions => {field => value})
    end
    
    class ValidationCollection
      def initialize(model, field)
        @model, @field = model, field
        @value_streams = []
      end
      
      def add(validation_method, config)
        stream_class_name = validation_method.to_s.camelize + 'ValueStream'
        if ValidationCollection.const_defined?(stream_class_name)
          stream_class = ValidationCollection.const_get(stream_class_name)
          if stream_class == ValidatesUniquenessOfValueStream
            @validates_uniqueness_config = config
          else
            input = @value_streams.last
            @value_streams << stream_class.new(@model, @field, config, input)
          end
        end
      end
      
      def includes_presence?
        @value_streams.any? { |vs| vs.is_a?(ValidatesPresenceOfValueStream) }
      end
      
      def includes_uniqueness?
        @value_streams.any? { |vs| vs.is_a?(ValidatesUniquenessOfValueStream) }
      end
      
      def satisfying_value
        if @validates_uniqueness_config
          input = @value_streams.last
          @value_streams << ValidatesUniquenessOfValueStream.new(
            @model, @field, @validates_uniqueness_config, input
          )
          @validates_uniqueness_config = nil
        end
        @value_streams.last.satisfying_value if @value_streams.last
      end
      
      class ValueStream
        attr_reader :input
        
        def initialize(model, field, config, input)
          @model, @field, @config, @input = model, field, config, input
          @sequence_number = 0
        end
      
        def column
          @model.columns.detect { |c| c.name == @field.to_s }
        end
        
        def increment
          @sequence_number += 1
          input.increment if input
        end
      end
      
      class ValidatesEmailFormatOfValueStream < ValueStream
        def satisfying_value
          "john.doe#{@sequence_number}@example.com"
        end
      end
      
      class ValidatesInclusionOfValueStream < ValueStream
        def satisfying_value
          @config[:in].first
        end
      end
      
      class ValidatesPresenceOfValueStream < ValueStream
        def association
          @model.belongs_to_associations.detect { |a|
            a.association_foreign_key.to_sym == @field.to_sym
          }
        end
        
        def increment
          if association
            association.klass.create_sample
          else
            super
          end
        end
      
        def satisfying_associated_value
          value = association.klass.last || association.klass.sample
          value = value.id if value
          value
        end
      
        def satisfying_value
          prev_value = input.satisfying_value if input
          if association
            satisfying_associated_value
          else
            if prev_value.present?
              prev_value
            elsif column && column.type == :date
              Date.today + @sequence_number
            elsif column && column.type == :datetime
              Time.utc(1970, 1, 1) + @sequence_number.days
            elsif column && column.type == :integer
              @sequence_number
            else
              "#{@field} #{@sequence_number}"
            end
          end
        end
      end
      
      class ValidatesUniquenessOfValueStream < ValueStream
        def satisfying_value
          value = input.satisfying_value if input
          if !@model.unique?(@field, value)
            my_input = input || ValidatesPresenceOfValueStream.new(@model, @field, nil, @input)
            until @model.unique?(@field, value)
              my_input.increment
              value = my_input.satisfying_value
            end
          end
          value
        end
      end
    end
  end
end
