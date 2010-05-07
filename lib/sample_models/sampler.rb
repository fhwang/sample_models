module SampleModels
  class Sampler
    attr_accessor :before_save
    attr_reader   :configured_default_attrs, :model_class
    
    def initialize(model_class)
      @model_class = model_class
      @configured_default_attrs = {}
    end
    
    def add_has_many_subselect(value, assoc, find_query)
      if value.empty?
        not_matching_subselect = @model_class.send(
          :construct_finder_sql,
          :select => "#{@model_class.table_name}.id", :joins => assoc.name,
          :group => "#{@model_class.table_name}.id"
        )
        find_query.condition_sqls << "id not in (#{not_matching_subselect})"
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
        matching_subselect =
          "id in (select matching.id from (#{matching_inner_subselect}) as matching where matching.count = #{value.size})"
        find_query.condition_sqls << matching_subselect
        not_matching_subselect = @model_class.send(
          :construct_finder_sql,
          :select => "#{@model_class.table_name}.id", :joins => assoc.name,
          :conditions => [
            "#{assoc.klass.table_name}.id not in (?)", value.map(&:id)
          ],
          :group => "#{@model_class.table_name}.id"
        )
        find_query.condition_sqls << "id not in (#{not_matching_subselect})"
      end
    end
    
    def belongs_to_assoc_for(column_or_name)
      name_to_match = nil
      if column_or_name.is_a?(String) or column_or_name.is_a?(Symbol)
        name_to_match = column_or_name.to_sym
      else
        name_to_match = column_or_name.name.to_sym
      end
      model.belongs_to_associations.detect { |a|
        a.name.to_sym == name_to_match ||
        a.primary_key_name.to_sym == name_to_match
      }
    end
    
    def create_sample(attrs)
      attrs = reify_association_hashes attrs
      orig_attrs = HashWithIndifferentAccess.new attrs
      attrs = orig_attrs.clone
      model.validation_collections.each do |field, validation_collection|
        unless attrs.has_key?(field)
          attrs[field] = validation_collection.satisfying_value
        end
      end
      instance = model_class.new attrs
      if before_save
        if before_save.arity == 1
          before_save.call instance
        else
          before_save.call instance, orig_attrs
        end
      end
      instance.save!
      update_associations(instance, attrs, orig_attrs)
      instance
    end
    
    def model
      SampleModels.models[@model_class]
    end
    
    def reify_association_hashes(attrs)
      a = attrs.clone
      model.belongs_to_associations.each do |assoc|
        if (value = a[assoc.name]) && value.is_a?(Hash)
          a[assoc.name] = assoc.klass.sample(value)
        end
      end
      model.has_many_associations.each do |assoc|
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
      model.belongs_to_associations.each do |assoc|
        if attrs.keys.include?(assoc.name.to_s)
          find_query.conditions[assoc.primary_key_name] = if attrs[assoc.name]
            attrs[assoc.name].id
          else
            attrs[assoc.name]
          end
        end
      end
      model.has_many_associations.each do |assoc|
        if attrs.keys.include?(assoc.name.to_s)
          add_has_many_subselect attrs[assoc.name], assoc, find_query
        end
      end
      instance = @model_class.first find_query.to_hash
      if instance
        needs_save = false
        model.belongs_to_associations.each do |assoc|
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
      model.belongs_to_associations.each do |assoc|
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

