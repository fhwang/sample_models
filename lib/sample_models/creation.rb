require 'delegate'

module SampleModels
  class Creation
    def initialize(sampler, *args)
      @sampler = sampler
      @specified_attrs = SpecifiedAttributes.new(sampler, *args).result
    end
    
    def deferred_belongs_to_assocs
      @deferred_belongs_to_assocs ||= begin
        model.belongs_to_associations.select { |a|
          @instance.send(a.foreign_key).nil? &&
            !@specified_attrs.member?(a.foreign_key) &&
            !@specified_attrs.member?(a.name) && 
            !@sampler.defaults.member?(a.name)
        }
      end
    end
    
    def model
      @sampler.model
    end
    
    def run
      attrs = @specified_attrs.clone
      @sampler.defaults.each do |attr, val|
        attrs[attr] = val unless attrs.member?(attr)
      end
      columns_to_fill = model.columns.clone
      model.validated_attr_accessors.each do |attr|
        columns_to_fill << VirtualColumn.new(attr)
      end
      columns_to_fill.each do |column|
        unless attrs.member?(column.name) || 
               specified_association_value?(column.name)
          sequence = @sampler.first_pass_attribute_sequence(column)
          attrs[column.name] = sequence.next
        end
      end
      @instance = model.new(attrs)
      save!
      update_with_deferred_associations!
      @instance
    end
    
    def save!
      if @sampler.before_save
        if @sampler.before_save.arity == 1
          @sampler.before_save.call(@instance)
        else
          @sampler.before_save.call(@instance, @specified_attrs)
        end
      end
      @instance.save!
    end
    
    def specified_association_value?(column_name)
      @specified_attrs.any? { |attr, val|
        if assoc = model.belongs_to_association(attr)
          assoc.foreign_key == column_name
        end
      }
    end
  
    def update_with_deferred_associations!
      unless deferred_belongs_to_assocs.empty?
        deferred_belongs_to_assocs.each do |a|
          if a.polymorphic?
            klass = @sampler.polymorphic_default_classes[a.name]
            klass ||= SampleModels.samplers.values.map(&:model).detect { |m|
              m != @sampler.model
            }
            @instance.send("#{a.name}=", klass.sample)
          else
            column = model.columns.detect { |c| c.name == a.foreign_key }
            @instance.send(
              "#{a.foreign_key}=", 
              @sampler.second_pass_attribute_sequence(column).next
            )
          end
        end
        save!
      end
    end
    
    class SpecifiedAttributes
      attr_reader :result
      
      def initialize(sampler, *args)
        @sampler = sampler
        @result = if args.first.is_a?(Symbol)
          sample_name = args.shift
          @sampler.named_samples[sample_name].clone
        else
          {}
        end
        @result.merge!(args.pop) if args.last.is_a?(Hash)
        args.each do |associated_value|
          assign_associated_record_from_args(associated_value)
        end
        model.belongs_to_associations.each do |assoc|
          build_belongs_to_record_from_shortcut_args(assoc)
        end
        model.has_many_associations.each do |assoc|
          build_has_many_record_from_shortcut_args(assoc)
        end
        @result = HashWithIndifferentAccess.new(@result)
      end
      
      def assign_associated_record_from_args(associated_value)
        assocs = model.associations.select { |a|
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
      
      def build_belongs_to_record_from_shortcut_args(assoc)
        if value = @result[assoc.name]
          if value.is_a?(Hash)
            @result[assoc.name] = assoc.klass.sample(value)
          elsif value.is_a?(Array)
            @result[assoc.name] = assoc.klass.sample(*value)
          end
        end
      end
      
      def build_has_many_record_from_shortcut_args(assoc)
        if values = @result[assoc.name]
          @result[assoc.name] = values.map { |value|
            value.is_a?(Hash) ? assoc.klass.sample(value) : value
          }
        end
      end
      
      def model
        @sampler.model
      end
    end

    class VirtualColumn
      attr_reader :name
      
      def initialize(name)
        @name = name
      end
      
      def type
        :string
      end
    end
  end
end
