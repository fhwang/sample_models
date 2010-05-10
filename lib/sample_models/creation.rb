module SampleModels
  class Creation
    def initialize(sampler, attrs)
      @sampler, @attrs = sampler, attrs
    end
    
    def model
      SampleModels.models[@sampler.model_class]
    end
    
    def run
      attrs = Sampler.reify_association_hashes model, @attrs
      orig_attrs = HashWithIndifferentAccess.new attrs
      attrs = orig_attrs.clone
      model.validation_collections.each do |field, validation_collection|
        unless attrs.has_key?(field)
          attrs[field] = validation_collection.satisfying_value
        end
      end
      @sampler.configured_default_attrs.each do |attr, val|
        unless attrs.has_key?(attr)
          attrs[attr] = val
        end
      end
      model.columns.each do |column|
        unless attrs.has_key?(column.name)
          case column.type
          when :string
            attrs[column.name] = "#{column.name}"
          when :integer
            unless model.belongs_to_associations.any? { |assoc|
              assoc.primary_key_name == column.name
            }
              attrs[column.name] = 1
            end
          when :datetime
            attrs[column.name] = Time.now.utc
          when :float
            attrs[column.name] = 1.0
          end
        end
      end
      instance = @sampler.model_class.new attrs
      @sampler.save! instance, orig_attrs
      update_associations(instance, attrs, orig_attrs)
      instance
    end
    
    def update_associations(instance, attrs, orig_attrs)
      proxied_associations = []
      needs_another_save = false
      model.belongs_to_associations.each do |assoc|
        unless instance.send(assoc.name) || attrs.has_key?(assoc.name) ||
               attrs.has_key?(assoc.association_foreign_key) ||
               @sampler.model_class == assoc.klass
          needs_another_save = true
          instance.send("#{assoc.name}=", assoc.klass.sample)
        end
      end
      if needs_another_save
        @sampler.save! instance, orig_attrs
      end
    end
  end
end
