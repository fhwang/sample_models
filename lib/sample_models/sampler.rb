module SampleModels
  class Sampler
    attr_accessor :before_save
    attr_reader   :configured_default_attrs, :model_class
    
    def initialize(model_class)
      @model_class = model_class
      @configured_default_attrs = {}
      @validation_collections = Hash.new { |h,k|
        h[k] = ValidationCollection.new(@model_class, k)
      }
    end
    
    def belongs_to_assoc_for(column_or_name)
      name_to_match = nil
      if column_or_name.is_a?(String) or column_or_name.is_a?(Symbol)
        name_to_match = column_or_name.to_sym
      else
        name_to_match = column_or_name.name.to_sym
      end
      Model.belongs_to_associations(@model_class).detect { |a|
        a.name.to_sym == name_to_match ||
        a.primary_key_name.to_sym == name_to_match
      }
    end
    
    def create_sample(attrs)
      attrs = reify_association_hashes attrs
      orig_attrs = HashWithIndifferentAccess.new attrs
      attrs = orig_attrs.clone
      @validation_collections.each do |field, validation_collection|
        unless attrs.has_key?(field)
          attrs[field] = validation_collection.satisfying_value
        end
      end
      instance = model_class.new attrs
      before_save.call(instance, orig_attrs) if before_save
      instance.save!
      update_associations(instance, attrs, orig_attrs)
      instance
    end
    
    def record_validation(*args)
      type = args.shift
      config = args.extract_options!
      fields = args
      fields.each do |field|
        @validation_collections[field].add(type, config)
      end
    end
    
    def reify_association_hashes(attrs)
      a = attrs.clone
      Model.belongs_to_associations(@model_class).each do |assoc|
        if (value = a[assoc.name]) && value.is_a?(Hash)
          a[assoc.name] = assoc.klass.sample(value)
        end
      end
      Model.has_many_associations(@model_class).each do |assoc|
        if values = a[assoc.name]
          a[assoc.name] = values.map { |value|
            value.is_a?(Hash) ? assoc.klass.sample(value) : value
          }
        end
      end
      a
    end
    
    def sample(attrs)
      attrs = reify_association_hashes attrs
      attrs = HashWithIndifferentAccess.new attrs
      find_query = ARQuery.new
      attrs.each do |k,v|
        if @model_class.column_names.include?(k.to_s)
          find_query.conditions[k] = v
        end
      end
      Model.belongs_to_associations(@model_class).each do |assoc|
        if attrs.keys.include?(assoc.name.to_s)
          find_query.conditions[assoc.primary_key_name] = if attrs[assoc.name]
            attrs[assoc.name].id
          else
            attrs[assoc.name]
          end
        end
      end
      Model.has_many_associations(@model_class).each do |assoc|
        if attrs.keys.include?(assoc.name.to_s)
          value = attrs[assoc.name]
          if value.empty?
            not_matching_subselect = @model_class.send(
              :construct_finder_sql,
              :select => "#{@model_class.table_name}.id",
              :joins => assoc.name,
              :group => "#{@model_class.table_name}.id"
            )
            find_query.condition_sqls <<
                "id not in (#{not_matching_subselect})"
          else
            matching_inner_subselect = @model_class.send(
              :construct_finder_sql,
              :select =>
                  "#{@model_class.table_name}.id, count(#{assoc.klass.table_name}.id) as count",
              :joins => assoc.name,
              :conditions => [
                "#{assoc.klass.table_name}.id in (?)", value.map(&:id)
              ],
              :group => "#{@model_class.table_name}.id"
            )
            matching_subselect = "id in (select matching.id from (#{matching_inner_subselect}) as matching where matching.count = #{value.size})"
            find_query.condition_sqls << matching_subselect
            not_matching_subselect = @model_class.send(
              :construct_finder_sql,
              :select => "#{@model_class.table_name}.id",
              :joins => assoc.name,
              :conditions => [
                "#{assoc.klass.table_name}.id not in (?)", value.map(&:id)
              ],
              :group => "#{@model_class.table_name}.id"
            )
            find_query.condition_sqls <<
                "id not in (#{not_matching_subselect})"
          end
        end
      end
      instance = @model_class.first find_query.to_hash
      if instance
        needs_save = false
        Model.belongs_to_associations(@model_class).each do |assoc|
          if instance.send(assoc.primary_key_name) && 
             !instance.send(assoc.name)
           instance.send("#{assoc.name}=", assoc.klass.sample)
          end
        end
      else
        instance = create_sample attrs
      end
      instance
    end
    
    def update_associations(instance, attrs, orig_attrs)
      proxied_associations = []
      needs_another_save = false
      Model.belongs_to_associations(@model_class).each do |assoc|
        unless instance.send(assoc.name) || attrs.has_key?(assoc.name) ||
               attrs.has_key?(assoc.association_foreign_key) ||
               @model_class == assoc.klass
          needs_another_save = true
          instance.send("#{assoc.name}=", assoc.klass.sample)
        end
      end
      if needs_another_save
        before_save.call(instance, orig_attrs) if before_save
        instance.save!
      end
    end
  end
end

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
