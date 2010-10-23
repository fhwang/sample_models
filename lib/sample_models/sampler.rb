module SampleModels
  class Sampler
    def self.reify_association_hashes(model, attrs)
      a = attrs.clone
      model.belongs_to_associations.each do |assoc|
        if value = a[assoc.name]
          if value.is_a?(Hash)
            a[assoc.name] = assoc.klass.sample(value)
          elsif value.is_a?(Array)
            a[assoc.name] = assoc.klass.sample(*value)
          end
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
            begin
              a.klass == associated_value.class
            rescue NameError
              false
            end
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
  end
end

