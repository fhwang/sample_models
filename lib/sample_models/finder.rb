module SampleModels
  class Finder
    def initialize(model, attrs)
      @model = model
      attrs = Sampler.reify_association_hashes @model, attrs.clone
      @attrs = SampleModels.hash_with_indifferent_access_class.new attrs
      @ar_query = ARQuery.new
    end
    
    def add_empty_has_many_subselect(assoc)
      value = @attrs[assoc.name]
      not_matching_subselect = @model.construct_finder_sql(
        :select => "#{@model.table_name}.id", :joins => assoc.name,
        :group => "#{@model.table_name}.id"
      )
      @ar_query.condition_sqls << "id not in (#{not_matching_subselect})"
    end
    
    def add_non_empty_has_many_subselect(assoc)
      @ar_query.condition_sqls << has_many_matching_subselect(assoc)
      value = @attrs[assoc.name]
      not_matching_subselect = @model.construct_finder_sql(
        :select => "#{@model.table_name}.id", :joins => assoc.name,
        :conditions => [
          "#{assoc.klass.table_name}.id not in (?)", value.map(&:id)
        ],
        :group => "#{@model.table_name}.id"
      )
      @ar_query.condition_sqls << "id not in (#{not_matching_subselect})"
    end
    
    def attach_belongs_to_associations_to_query
      @model.belongs_to_associations.each do |assoc|
        if @attrs.keys.include?(assoc.name.to_s)
          @ar_query.conditions[assoc.primary_key_name] = if @attrs[assoc.name]
            @attrs[assoc.name].id
          else
            @attrs[assoc.name]
          end
        end
      end
    end
    
    def attach_non_associated_attrs_to_query
      @attrs.each do |k,v|
        if @model.column_names.include?(k.to_s)
          @ar_query.conditions[k] = v
        end
      end
    end
    
    def has_many_matching_subselect(assoc)
      value = @attrs[assoc.name]
      matching_inner_subselect = @model.construct_finder_sql(
        :select =>
          "#{@model.table_name}.id, count(#{assoc.klass.table_name}.id) as count",
        :joins => assoc.name,
        :conditions => [
          "#{assoc.klass.table_name}.id in (?)", value.map(&:id)
        ],
        :group => "#{@model.table_name}.id"
      )
      "id in (select matching.id from (#{matching_inner_subselect}) as matching where matching.count = #{value.size})"
    end

    def instance
      attach_non_associated_attrs_to_query
      attach_belongs_to_associations_to_query
      @model.has_many_associations.each do |assoc|
        if @attrs.keys.include?(assoc.name.to_s)
          if @attrs[assoc.name].empty?
            add_empty_has_many_subselect assoc
          else
            add_non_empty_has_many_subselect assoc
          end
        end
      end
      @model.first @ar_query.to_hash
    end
  end
end
