module SampleModels
  class Attributes
    attr_reader :proxied_associations, :required, :suggested
    
    def initialize(model_class, force_create, custom_attrs = {})
      @model_class, @force_create = model_class, force_create
      @required = {}
      @suggested = {}
      @proxied_associations = {}
      build_from_custom_attrs custom_attrs
      build_from_configured_defaults
      build_from_inferred_defaults
    end
    
    def build_from_configured_defaults
      config_defaults = ConfiguredDefaults.new sampler
      config_defaults.values.each do |name, value|
        unless has_value?(name) or has_proxied_association?(name)
          @required[name] = value 
        end
      end
    end
    
    def build_from_custom_attrs(custom_attrs)
      CustomAttributes.new(sampler, custom_attrs).each do |name, value|
        @required[name] = value
      end
    end
    
    def build_from_inferred_defaults
      inf_defaults = InferredDefaults.new(sampler, @force_create)
      inf_defaults.proxied_associations.each do |name, proxied_association|
        unless has_proxied_association?(name)
          @proxied_associations[name] = proxied_association
        end
      end
      inf_defaults.values.each do |name, value|
        @suggested[name] = value unless has_value?(name)
      end
    end
    
    def has_proxied_association?(key)
      @proxied_associations.has_key?(key.to_sym) ||
          ((assoc = sampler.belongs_to_assoc_for(key)) && (@required.has_key?(assoc.name) || @required.has_key?(assoc.primary_key_name.to_sym)))
    end
    
    def has_value?(key)
      @required.has_key?(key.to_sym)
    end
    
    def sampler
      SampleModels.samplers[@model_class]
    end
    
    def set_instance_attributes(instance)
      instance.attributes = @suggested.merge @required
      sampler.missing_fields_from_conditional_validated_presences(
        instance
      ).each do |field|
        column = @model_class.columns_hash[field.to_s]
        instance[field] = InferredDefaultValue.new(
          sampler, false, column
        ).value
      end
    end
    
    class ConfiguredDefaults
      attr_reader :values
      
      def initialize(sampler)
        @sampler = sampler
        @values = {}
        @sampler.configured_default_attrs.each do |name, value|
          build_from_configured_default name, value
        end
        @sampler.force_on_create.each do |assoc_name|
          assoc = @sampler.belongs_to_assoc_for assoc_name
          @values[assoc_name] = 
            SampleModels.samplers[assoc.klass].default_creation.instance
        end
      end
    
      def build_from_configured_default(name, value)
        if assoc = @sampler.belongs_to_assoc_for(name)
          value = value.call if value.is_a?(Proc)
          value = value.id unless value.nil?
          @values[name] = value
        else
          value = value.call if value.is_a?(Proc)
          @values[name] = value
        end
      end
    end
    
    class CustomAttributes < DelegateClass(Hash)
      def initialize(sampler, custom_attrs)
        @values = {}
        super @values
        custom_attrs.each do |field_name, value|
          if value.is_a?(Hash) &&
             assoc = sampler.belongs_to_assoc_for(field_name)
            assoc_class = Module.const_get assoc.class_name
            sampler_for_assoc = SampleModels.samplers[assoc_class]
            @values[field_name] = sampler_for_assoc.sample value
          else
            @values[field_name] = value
          end
        end
      end
    end
    
    class InferredDefault
      def initialize(sampler, force_create, column)
        @sampler, @force_create, @column =
            sampler, force_create, column
      end
      
      def belongs_to_assoc
        @belongs_to_assoc ||= @sampler.belongs_to_assoc_for(@column)
      end
      
      def has_belongs_to_assoc_without_always_validated_presence?
        belongs_to_assoc &&
            !@sampler.model_always_validates_presence_of?(@column.name)
      end
      
      def has_proxied_association?
        has_belongs_to_assoc_without_always_validated_presence? &&
            (belongs_to_assoc.class_name != @sampler.model_class.name)
      end
      
      def has_value?
        !has_belongs_to_assoc_without_always_validated_presence? &&
            @column.type != :boolean
      end
      
      def proxied_association
        ProxiedAssociation.new belongs_to_assoc
      end
      
      def value
        InferredDefaultValue.new(@sampler, @force_create, @column).value
      end
    end
    
    class InferredDefaults
      attr_reader :proxied_associations, :values
      
      def initialize(sampler, force_create)
        @sampler, @force_create = sampler, force_create
        @proxied_associations = {}
        @values = {}
        uninferrable_columns = %w(
          id created_at created_on updated_at updated_on
        )
        @sampler.model_class.columns.each do |column|
          unless uninferrable_columns.include?(column.name)
            build_inferred_attribute_or_proxied_association(column)
          end
        end
      end
      
      def build_inferred_attribute_or_proxied_association(column)
        name = column.name.to_sym
        inferred_default = InferredDefault.new @sampler, @force_create, column
        if inferred_default.has_proxied_association?
          @proxied_associations[name] = inferred_default.proxied_association
        elsif inferred_default.has_value?
          @values[name] = inferred_default.value
        end
      end
    end
    
    class InferredDefaultValue
      def initialize(sampler, force_create, column)
        @sampler, @force_create, @column = sampler, force_create, column
      end
      
      def value
        udf = @sampler.unconfigured_default_based_on_validations @column
        udf || case @column.type
          when :binary, :string, :text
            value_for_text
          when :date
            Date.today
          when :datetime
            Time.now.utc
          when :float
            0.0
          when :integer
            value_for_integer
          else
            raise "No default value for type #{ @column.type.inspect }"
        end
      end
      
      def value_for_integer
        if assoc = @sampler.belongs_to_assoc_for( @column )
          assoc_class = Module.const_get assoc.class_name
          if @force_create &&
             @sampler.model_validates_uniqueness_of?(@column.name)
            SampleModels.samplers[assoc_class].sample({}, true).id
          else
            SampleModels.samplers[assoc_class].default_creation.verified_instance.id
          end
        else
          0
        end
      end
      
      def value_for_text
        if @force_create and
           @sampler.model_validates_uniqueness_of?(@column.name)
          SampleModels.random_word
        else
          "Test #{ @column.name }"
        end
      end
    end
  end
end
