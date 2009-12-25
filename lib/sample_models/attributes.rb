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
        instance.send(
          "#{field}=", InferredDefaultValue.new(sampler, false, field).value
        )
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
          elsif value.is_a?(Array) &&
                assoc = sampler.has_many_through_assoc_for(field_name)
            assoc_class = Module.const_get assoc.class_name
            sampler_for_assoc = SampleModels.samplers[assoc_class]
            @values[field_name] = value.map { |h| sampler_for_assoc.sample(h) }
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
      
      def has_belongs_to_assoc_that_can_be_set_after_initial_creation?
        belongs_to_assoc &&
            !@sampler.model_always_validates_presence_of?(@column.name)
      end
      
      def proxied_association
        ProxiedAssociation.new belongs_to_assoc
      end
      
      def should_use_value?
        @column.type != :boolean
      end
      
      def value
        InferredDefaultValue.new(
          @sampler, @force_create, @column.name.to_sym
        ).value
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
            try_setting_inferred_default(column)
          end
        end
      end
      
      def try_setting_inferred_default(column)
        name = column.name.to_sym
        i_d = InferredDefault.new @sampler, @force_create, column
        if i_d.has_belongs_to_assoc_that_can_be_set_after_initial_creation?
          @proxied_associations[name] = i_d.proxied_association
        elsif i_d.should_use_value?
          @values[name] = i_d.value
        end
      end
    end
    
    class InferredDefaultValue
      def initialize(sampler, force_create, column_name)
        @sampler, @force_create, @column_name =
            sampler, force_create, column_name
      end
      
      def column
        @column ||= @sampler.model_class.columns_hash[@column_name.to_s]
      end
      
      def needs_random_unique_value?
        @force_create && @sampler.model_validates_uniqueness_of?(@column_name)
      end
      
      def value
        udf = @sampler.unconfigured_default_based_on_validations @column_name
        udf || if column
          case column.type
            when :binary, :string, :text
              value_for_text
            when :date
              value_for_date
            when :datetime
              value_for_time
            when :float
              value_for_float
            when :integer
              value_for_integer
            else
              raise "No default value for type #{ column.type.inspect }"
          end
        else
          value_for_text
        end
      end
      
      def value_for_date
        value_for_time.send :to_date
      end
      
      def value_for_float
        if needs_random_unique_value?
          rand
        else
          0.0
        end
      end
      
      def value_for_time
        if needs_random_unique_value?
          Time.utc(1970 + rand(50), rand(12) + 1, rand(28) + 1)
        else
          Time.now.utc
        end
      end
      
      def value_for_integer
        if assoc = @sampler.belongs_to_assoc_for( column )
          assoc_class = Module.const_get assoc.class_name
          if needs_random_unique_value?
            SampleModels.samplers[assoc_class].sample({}, true).id
          else
            SampleModels.samplers[assoc_class].default_creation.verified_instance.id
          end
        else
          0
        end
      end
      
      def value_for_text
        if needs_random_unique_value?
          SampleModels.random_word
        else
          "Test #{ @column_name }"
        end
      end
    end
  end
end
