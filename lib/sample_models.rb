if RAILS_ENV == 'test' # no reason to run this code outside of test mode

require 'delegate'
  
module SampleModels
  mattr_reader   :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(model_class)
  }

  def self.configure(model_class, opts ={})
    yield ConfigureRecipient.new(model_class) if block_given?
  end
  
  def self.random_word(length = 20)
    letters = 'abcdefghijklmnopqrstuvwxyz'.split //
    (1..length).to_a.map { letters[rand(letters.size)] }.join( '' )
  end
  
  protected
  
  def self.included( mod )
    mod.extend ARClassMethods
    super
  end
  
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
          SampleModels.samplers[assoc_class].default_creation.verified_instance.id
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
  
  module ARClassMethods
    def create_sample(attrs = {})
      SampleModels.samplers[self].sample attrs, true
    end
    
    def sample( attrs = {} )
      SampleModels.samplers[self].sample attrs
    end
  end
  
  class ConfigureRecipient
    def initialize( model_class )
      @model_class = model_class
      @default_recipient = Default.new @model_class
    end
    
    def before_save(&proc)
      sampler.before_save = proc
    end
    
    def default
      block_given? ? yield(@default_recipient) : @default_recipient
    end
    
    def default_to_nil(*fields)
      fields.each do |field| self.default.send(field, nil); end
    end
    
    def force_on_create(foc)
      foc = [foc].compact unless foc.is_a?(Array)
      sampler.force_on_create = foc
    end
    
    def force_unique(fu)
      fu = [fu].compact unless fu.is_a?(Array)
      sampler.force_unique = fu
    end
    
    def sampler
      SampleModels.samplers[@model_class]
    end
    
    class Default
      def initialize( model_class )
        @model_class = model_class
      end
      
      def method_missing( meth, *args )
        if @model_class.column_names.include?( meth.to_s ) or
           sampler.belongs_to_assoc_for(meth) or
           @model_class.public_method_defined?("#{meth}=")
          default = if args.size == 1
            args.first
          else
            Proc.new do; yield; end
          end
          sampler.configured_default_attrs[meth] = default
        else
          raise(
            NoMethodError, "undefined method `#{meth}' for #{@model_class.name}"
          )
        end
      end
      
      def sampler
        SampleModels.samplers[@model_class]
      end
    end
  end
  
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
  
  class ProxiedAssociation
    def initialize(assoc)
      @assoc = assoc
    end
    
    def assoc_class
      Module.const_get @assoc.class_name
    end
    
    def name
      @assoc.name
    end
    
    def instance
      SampleModels.samplers[assoc_class].default_creation.verified_instance
    end
  end
  
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
    
    def sample(custom_attrs, force_create = false)
      force_create = true if !custom_attrs.empty?
      SampleModels::CustomCreation.new(self, custom_attrs, force_create).run
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
    
    def missing_fields_from_conditional_validated_presences(instance)
      @validations_hash.select { |column_name, validations|
        validations.any? { |validation|
          validation.presence? && validation.conditional? && validation.should_be_applied?(instance)
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
      field = args[1]
      @validations_hash[field] << Validation.new(*args)
    end
    
    def unconfigured_default_based_on_validations(column)
      validations = @validations_hash[column.name.to_sym]
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
  
  class Validation
    attr_reader :config
    
    def initialize(*args)
      @type = args.shift
      @field = args.shift
      @config = args.shift || {:on => :save}
    end
    
    def as_email?
      @type == :validates_email_format_of
    end
    
    def conditional?
      @config[:if] || @config[:unless]
    end
    
    def inclusion?
      @type == :validates_inclusion_of
    end
    
    def on
      @config[:on]
    end
    
    def presence?
      @type == :validates_presence_of
    end
    
    def satisfies_condition?(condition, instance)
      if condition.is_a?(Symbol)
        instance.send condition
      else
        condition.call instance
      end
    end
    
    def should_be_applied?(instance)
      (@config[:if] && satisfies_condition?(@config[:if], instance)) ||
      (@config[:unless] && !satisfies_condition?(@config[:unless], instance)) ||
      @config[:if].nil? && @config[:unless].nil?
    end
    
    def unique?
      @type == :validates_uniqueness_of
    end
  end
end

module ActiveRecord
  class Base
    include SampleModels
  end
  
  module Validations
    module ClassMethods
      [:validates_email_format_of,
       :validates_inclusion_of, :validates_presence_of, 
       :validates_uniqueness_of].each do |validation|
        if method_defined?(validation)
          define_method "#{validation}_with_sample_models".to_sym do |*args|
            send "#{validation}_without_sample_models".to_sym, *args
            SampleModels.samplers[self].record_validation(
              validation, *args
            )
          end
          alias_method_chain validation, :sample_models
        end
      end
    end
  end
end

end # if RAILS_ENV == 'test'
