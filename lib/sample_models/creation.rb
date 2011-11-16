module SampleModels
  class Creation
    def initialize(sampler, attrs)
      @sampler = sampler
      @orig_attrs = SampleModels.hash_with_indifferent_access_class.new attrs
      @attrs = Attributes.new(@sampler, attrs)
    end
    
    def model
      SampleModels.models[@sampler.model_class]
    end
    
    def polymorphic_assoc_value(assoc)
      if klass = @sampler.polymorphic_default_classes[assoc.name]
        klass.sample
      else
        SampleModels.samplers.values.map(&:model_class).detect { |m|
          m != @sampler.model_class
        }.sample
      end
    end
    
    def run
      @instance = @sampler.model_class.new @attrs.to_hash
      save!
      update_associations
      @instance
    end
    
    def save!
      @sampler.save!(@instance, @orig_attrs)
    end
    
    def update_associations
      needs_another_save = false
      model.belongs_to_associations.each do |assoc|
        unless @instance.send(assoc.name) || @attrs.has_key?(assoc.name) ||
               @attrs.has_key?(assoc.association_foreign_key)
          if assoc.options[:polymorphic]
            needs_another_save = true
            @instance.send "#{assoc.name}=", polymorphic_assoc_value(assoc)
          elsif @sampler.model_class != assoc.klass
            needs_another_save = true
            @instance.send "#{assoc.name}=", assoc.klass.sample
          end
        end
      end
      save! if needs_another_save
    end
    
    class Attributes < SampleModels.hash_with_indifferent_access_class
      def initialize(sampler, hash)
        @sampler = sampler
        hash = Sampler.reify_association_hashes model, hash
        super(hash)
        fill_based_on_validations
        fill_based_on_configured_defaults
        model.columns.each do |column|
          unless has_key?(column.name)
            fill_based_on_column_type column
          end
        end
      end
    
      def model
        SampleModels.models[@sampler.model_class]
      end
    
      def fill_based_on_column_type(column)
        case column.type
        when :string
          fill_based_on_string_column_type(column)
        when :integer
          unless model.belongs_to_associations.any? { |assoc|
            foreign_key = if assoc.respond_to?(:foreign_key)
              assoc.foreign_key
            else
              assoc.primary_key_name
            end
            foreign_key == column.name
          }
            self[column.name] = 1
          end
        when :datetime
          self[column.name] = Time.now.utc
        when :float
          self[column.name] = 1.0
        end
      end
    
      def fill_based_on_configured_defaults
        @sampler.configured_default_attrs.each do |attr, val|
          self[attr] = val unless has_key?(attr)
        end
      end
    
      def fill_based_on_string_column_type(column)
        unless model.belongs_to_associations.any? { |assoc|
          assoc.options[:polymorphic] &&
            assoc.options[:foreign_type] = column.name
        }
          self[column.name] = "#{column.name}"
        end
      end
    
      def fill_based_on_validations
        model.validation_collections.each do |field, validation_collection|
          assoc_key = nil
          if assoc = model.belongs_to_associations.detect { |a|
            a.association_foreign_key == field.to_s
          }
            assoc_key = assoc.name
          end
          unless has_key?(field) || (assoc_key && has_key?(assoc_key))
            self[field] = validation_collection.satisfying_value
          end
        end
      end
    end
  end
end
