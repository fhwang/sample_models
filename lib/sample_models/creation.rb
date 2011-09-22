require 'delegate'

module SampleModels
  class Creation
    def initialize(sampler, *args)
      @sampler = sampler
      @specified_attrs = PreprocessedArgs.new(model, *args).result
    end
    
    def model
      @sampler.model
    end
    
    def run
      attrs = @specified_attrs.clone
      @sampler.defaults.each do |attr, val|
        attrs[attr] = val unless attrs.member?(attr)
      end
      model.columns.each do |column|
        sequence = @sampler.first_pass_attribute_sequence(column)
        attrs[column.name] = sequence.next unless attrs.member?(column.name)
      end
      @instance = model.create!(attrs)
      update_with_deferred_associations
      @instance
    end
  
    def update_with_deferred_associations
      deferred_assocs = model.belongs_to_associations.select { |a|
        @instance.send(a.foreign_key).nil? &&
          !@specified_attrs.member?(a.foreign_key) &&
          !@specified_attrs.member?(a.name) &&
          !@sampler.defaults.member?(a.name)
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
    
    class PreprocessedArgs
      attr_reader :result
      
      def initialize(model, *args)
        @model = model
        @result = HashWithIndifferentAccess.new(
          args.last.is_a?(Hash) ? args.pop : {}
        )
        args.each do |associated_value|
          assign_associated_record_from_args(associated_value)
        end
        @model.belongs_to_associations.each do |assoc|
          build_associated_record_from_shortcut_args(assoc)
        end
      end
      
      def assign_associated_record_from_args(associated_value)
        assocs = @model.associations.select { |a|
          begin
            a.klass == associated_value.class
          rescue NameError
            false
          end
        }
        if assocs.size == 1
          @result[assocs.first.name] = associated_value
        else
          raise "Not sure what to do with associated value #{associated_value.inspect}"
        end
      end
      
      def build_associated_record_from_shortcut_args(assoc)
        if value = @result[assoc.name]
          if value.is_a?(Hash)
            @result[assoc.name] = assoc.klass.sample(value)
          elsif value.is_a?(Array)
            @result[assoc.name] = assoc.klass.sample(*value)
          end
        end
      end
    end
  end
end
