module SampleModels
  class Sampler
    def self.reified_belongs_to_associations(model, attrs)
      assocs = {}
      model.belongs_to_associations.each do |assoc|
        if value = attrs[assoc.name]
          if value.is_a?(Hash)
            assocs[assoc.name] = assoc.klass.sample(value)
          elsif value.is_a?(Array)
            assocs[assoc.name] = assoc.klass.sample(*value)
          end
        end
      end
      assocs
    end
    
    def self.reify_association_hashes(model, attrs)
      a = attrs.clone
      reified_belongs_to_associations(model, attrs).each do |name, value|
        a[name] = value
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
      @named_sample_attrs = SampleModels.hash_with_indifferent_access_class.new
      @polymorphic_default_classes =
        SampleModels.hash_with_indifferent_access_class.new
    end
    
    def create_sample(*args)
      attrs = preprocessed_attributes(*args)
      Creation.new(self, attrs).run
    end
    
    def fix_deleted_associations(instance, orig_attrs)
      needs_save = false
      model.belongs_to_associations.each do |assoc|
        if instance.send(assoc.primary_key_name) && 
           !instance.send(assoc.name)
         instance.send("#{assoc.name}=", assoc.klass.sample)
         needs_save = true
        end
      end
      save!(instance, orig_attrs) if needs_save
    end
    
    def model
      SampleModels.models[@model_class]
    end
    
    def preprocessed_attributes(*args)
      if args.first.is_a?(Symbol)
        preprocessed_named_sample_attrs(args)
      else
        attrs = args.last.is_a?(Hash) ? args.pop : {}
        args.each do |associated_value|
          assocs = model.associations(associated_value.class)
          if assocs.size == 1
            attrs[assocs.first.name] = associated_value
          else
            raise "Not sure what to do with associated value #{associated_value.inspect}"
          end
        end
        attrs
      end
    end
    
    def preprocessed_named_sample_attrs(args)
      attrs = named_sample_attrs[args.shift]
      attrs = attrs.merge(args.first) unless args.empty?
      attrs
    end
    
    def sample(*args)
      attrs = preprocessed_attributes(*args)
      instance = Finder.new(model, attrs).instance
      if instance
        fix_deleted_associations(instance, attrs)
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
  end
end

