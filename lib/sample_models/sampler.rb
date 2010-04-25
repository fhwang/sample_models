=begin
module SampleModels
  class Sampler
    attr_accessor :before_save, :force_on_create, :force_unique
    attr_reader   :configured_default_attrs, :model_class
    attr_writer   :default_instance
    
    def initialize(model_class)
      @model_class = model_class
      @validations_hash = Hash.new { |h, field| h[field] = [] }
      @configured_default_attrs = {}
      @force_on_create = []
      @force_unique = []
    end
    
    def belongs_to_assoc_for( column_or_name )
      name_to_match = nil
      if column_or_name.is_a?(String) or column_or_name.is_a?(Symbol)
        name_to_match = column_or_name.to_sym
      else
        name_to_match = column_or_name.name.to_sym
      end
      belongs_to_associations.detect { |a|
        a.name.to_sym == name_to_match ||
        a.primary_key_name.to_sym == name_to_match
      }
    end
    
    def belongs_to_associations
      @model_class.reflect_on_all_associations.select { |assoc|
        assoc.macro == :belongs_to
      }
    end
    
    def clear_default_creation
      @default_creation = nil
    end
    
    def default_creation
      @default_creation ||= SampleModels::DefaultCreation.new(self)
      @default_creation
    end
    
    def default_instance
      if @default_instance
        begin
          @default_instance.reload
          @default_instance
        rescue ActiveRecord::RecordNotFound
          # return nil
        end
      end
    end
    
    def has_many_through_assoc_for(name)
      @model_class.reflect_on_all_associations.detect { |assoc|
        assoc.macro == :has_many && assoc.options[:through] &&
            assoc.name.to_sym == name
      }
    end
    
    def missing_fields_from_conditional_validated_presences(instance)
      @validations_hash.select { |column_name, validations|
        validations.any? { |validation|
          validation.presence? && validation.conditional? && validation.should_be_applied?(instance) &&
          instance.send(column_name).blank?
        }
      }.map { |column_name, *validations| column_name }
    end

    def model_always_validates_presence_of?(column_name)
      @validations_hash[column_name.to_sym].any? { |validation|
        validation.present? && !validation.conditional? &&
          validation.on == :save
      }
    end
    
    def model_validates_uniqueness_of?(column_name)
      unique_attributes.include?(column_name.to_sym)
    end
    
    def record_validation(*args)
      validation = Validation.new *args
      validation.fields.each do |field|
        @validations_hash[field] << validation
      end
    end
    
    def sample(custom_attrs, force_create = false)
      unless custom_attrs.empty? ||
             custom_attrs.keys.any? { |attr|
               model_validates_uniqueness_of?(attr)
             }
        force_create = true
      end
      SampleModels::CustomCreation.new(self, custom_attrs, force_create).run
    end
    
    def unconfigured_default_based_on_validations(column_name)
      validations = @validations_hash[column_name.to_sym]
      unless validations.empty?
        inclusion = validations.detect { |validation| validation.inclusion? }
        if inclusion
          inclusion.config[:in].first
        else
          as_email = validations.detect { |validation| validation.as_email? }
          if as_email
            "#{SampleModels.random_word}@#{SampleModels.random_word}.com"
          end
        end
      end
    end
    
    def unique_attributes
      @validations_hash.
          select { |name, validations|
            validations.any? { |validation| validation.unique? }
          }.
          map { |name, validations| name }.
          concat(@force_unique)
    end
  end
end
=end
