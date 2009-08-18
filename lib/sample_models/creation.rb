module SampleModels
  class Creation
    def initialize(sampler, custom_attrs={})
      @sampler, @custom_attrs = sampler, custom_attrs
    end
    
    def create!
      @instance = begin
        instance = model_class.new
        @attributes.set_instance_attributes instance
        if @sampler.before_save
          @sampler.before_save.call instance
        end
        instance.save!
        instance
      rescue ActiveRecord::RecordInvalid
        $!.to_s =~ /Validation failed: (.*)/
        raise "#{model_class.name} validation failed: #{$1}"
      end
      update_associations
      @instance
    end
    
    def find_or_create
      @attributes = Attributes.new model_class, @force_create, @custom_attrs
      Finder.new(@sampler, @attributes).find || create!
    end
    
    def instance
      run unless @instance
      @instance
    end
    
    def model_class
      @sampler.model_class
    end
    
    def update_associations
      needs_save = false
      each_updateable_association do |name, proxied_association|
        needs_save = true
        @instance.send("#{name}=", proxied_association.instance.id)
      end
      @instance.save! if needs_save
    end
    
    class Finder
      def initialize(sampler, attributes)
        @sampler, @attributes = sampler, attributes
      end
      
      def find
        unless @sampler.unique_attributes.empty?
          find_attributes = {}
          @sampler.unique_attributes.each do |name|
            find_attributes[name] =
                @attributes.required[name] || @attributes.suggested[name]
          end
          @instance = @sampler.model_class.find(
            :first, :conditions => find_attributes
          )
          update_existing_record if @instance
        end
        @instance
      end
    
      def update_existing_record
        differences = @attributes.required.select { |k, v|
          @instance.send(k) != v
        }
        unless differences.empty?
          differences.each do |k, v| @instance.send("#{k}=", v); end
          @instance.save
        end
      end
    end
  end
  
  class CustomCreation < Creation
    def initialize(sampler, custom_attrs, force_create)
      super sampler, custom_attrs
      @force_create = force_create
    end
    
    def each_updateable_association
      custom_keys = @custom_attrs.keys
      @attributes.proxied_associations.each do |name, proxied_association|
        unless custom_keys.include?(name) or
               custom_keys.include?(proxied_association.name)
          yield name, proxied_association
        end
      end
    end
    
    def run
      @instance = find_or_create
    end
  end
  
  class DefaultCreation < Creation
    def each_updateable_association
      @attributes.proxied_associations.each do |name, proxied_association|
        yield name, proxied_association
      end
    end
    
    def check_assoc_on_default_instance(ds, assoc)
      unless assoc.class_name == model_class.name
        assoc_class = Module.const_get assoc.class_name
        if ds.send(assoc.primary_key_name) &&
           !assoc_class.find_by_id(ds.send(assoc.name))
          ds.send(
            "#{assoc.name}=", 
            SampleModels.samplers[assoc_class].default_creation.instance
          )
          @recreated_associations = true
        end
      end
    end
    
    def run
      if ds = @sampler.default_instance
        @recreated_associations = false
        @sampler.belongs_to_associations.each do |assoc|
          check_assoc_on_default_instance(ds, assoc)
        end
        ds.save! if @recreated_associations
      else
        set_default
      end
      @instance = @sampler.default_instance
    end
    
    def set_default
      @sampler.default_instance = find_or_create
    end
    
    def verified_instance
      begin
        @instance && @instance.reload
      rescue ActiveRecord::RecordNotFound
        @instance = nil
      end
      instance
    end
  end
end
