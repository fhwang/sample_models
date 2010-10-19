module SampleModels
  class Sampler
    def self.reify_association_hashes(model, attrs)
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
    
    attr_accessor :before_save
    attr_reader   :configured_default_attrs, :model_class, :named_sample_attrs,
                  :polymorphic_default_classes
    
    def initialize(model_class)
      @model_class = model_class
      @configured_default_attrs = {}
      @named_sample_attrs = HashWithIndifferentAccess.new
      @polymorphic_default_classes = HashWithIndifferentAccess.new
    end
    
    def attrs_from_args(*args)
      if args.first.is_a?(Symbol)
        attrs = named_sample_attrs[args.shift]
        attrs = attrs.merge(args.first) unless args.empty?
        attrs
      else
        attrs = args.last.is_a?(Hash) ? args.pop : {}
        args.each do |associated_value|
          assocs = @model_class.reflect_on_all_associations.select { |a|
            a.klass == associated_value.class
          }
          if assocs.size == 1
            attrs[assocs.first.name] = associated_value
          else
            raise "Not sure what to do with associated value #{associated_value.inspect}"
          end
        end
        attrs
      end
    end
    
    def create_sample(attrs)
      Creation.new(self, attrs).run
    end
    
    def model
      SampleModels.models[@model_class]
    end
    
    def sample(attrs)
      instance = Finder.new(model, attrs).instance
      if instance
        needs_save = false
        model.belongs_to_associations.each do |assoc|
          if instance.send(assoc.primary_key_name) && 
             !instance.send(assoc.name)
           instance.send("#{assoc.name}=", assoc.klass.sample)
           needs_save = true
          end
        end
        save!(instance, attrs) if needs_save
      else
        instance = create_sample attrs
      end
      instance
    end
    
    def save!(instance, orig_attrs)
      if @before_save
        if @before_save.arity == 1
          @before_save.call instance
        else
          @before_save.call instance, orig_attrs
        end
      end
      instance.save!
    end
    
    class Finder
      def initialize(model, attrs)
        @model, @attrs = model, attrs.clone
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
        @attrs = Sampler.reify_association_hashes @model, @attrs
        @attrs = HashWithIndifferentAccess.new @attrs
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
end

