if RAILS_ENV == 'test' # no reason to run this code outside of test mode

require 'delegate'
  
module SampleModels
  mattr_accessor :configured_defaults
  self.configured_defaults = Hash.new { |h,k| h[k] = {} }
  mattr_accessor :default_samples
  self.default_samples = {}
  mattr_reader   :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(
      model_class, configured_defaults[model_class]
    )
  }

  def self.configure(model_class, opts ={})
    if foc = opts[:force_on_create]
      foc = [foc].compact unless foc.is_a?(Array)
      SampleModels.samplers[model_class].force_on_create = foc
    end
    yield ConfigureRecipient.new(model_class) if block_given?
  end
    
  def self.default_instance( model_class, &block )
    samplers[model_class].default_instance_proc = Proc.new { block.call }
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
  
  class Attributes < DelegateClass(Hash)
    attr_reader :proxied_associations
    
    def initialize(model_class, default, custom_attrs)
      @model_class, @default = model_class, default
      @attributes = {}
      super @attributes
      @proxied_associations = {}
      build_from_custom_attrs custom_attrs
      build_from_configured_defaults
      build_from_inferred_defaults
    end
    
    def build_attribute_or_proxied_association(name, column)
      proxied_association = false
      if assoc = sampler.belongs_to_assoc_for( column )
        unless sampler.model_validates_presence_of?(column.name)
          unless assoc.class_name == @model_class.name
            @proxied_associations[name.to_sym] = ProxiedAssociation.new(assoc)
          end
          proxied_association = true
        end
      end
      unless proxied_association
        default_att_value = nil
        if sampler.configured_default_attrs.key? name.to_sym
          cd = sampler.configured_default_attrs[name.to_sym]
          cd = cd.call if cd.is_a?( Proc )
          default_att_value = cd
        else
          default_att_value = unconfigured_default_for column
        end
        @attributes[name.to_sym] = default_att_value
      end
    end
    
    def build_from_configured_defaults
      sampler.configured_default_attrs.each do |name, value|
        if assoc = sampler.belongs_to_assoc_for(name)
          name = assoc.primary_key_name.to_sym
          value = value.id unless value.nil?
        elsif value.is_a?(Proc)
          value = value.call
        end
        @attributes[name] = value unless @attributes.has_key?(name)
      end
      sampler.force_on_create.each do |assoc_name|
        assoc = sampler.belongs_to_assoc_for assoc_name
        @attributes[assoc_name] ||= assoc.klass.default_sample
      end
    end
    
    def build_from_inferred_defaults
      @model_class.columns_hash.each do |name, column|
        unless name == 'id' or has_value_or_proxied_association?(name)
          build_attribute_or_proxied_association name, column
        end
      end
    end
    
    def build_from_custom_attrs(custom_attrs)
      custom_attrs ||= {}
      custom_attrs.each do |field_name, value|
        if value.is_a?(Hash) &&
           assoc = sampler.belongs_to_assoc_for(field_name)
          assoc_class = Module.const_get assoc.class_name
          sampler = SampleModels.samplers[assoc_class]
          @attributes[field_name] = sampler.custom_sample value
        else
          @attributes[field_name] = value
        end
      end
    end
    
    def has_value_or_proxied_association?(key)
      @attributes.has_key?(key.to_sym) ||
          @proxied_associations.has_key?(key.to_sym)
    end
    
    def sampler
      SampleModels.samplers[@model_class]
    end
    
    def unconfigured_default_for( column )
      udf = sampler.unconfigured_default_based_on_validations column
      udf || case column.type
        when :binary, :string, :text
          unconfigured_default_for_text(column)
        when :boolean
          true
        when :date
          Date.today
        when :datetime
          Time.now.utc
        when :float
          1.0
        when :integer
          if assoc = sampler.belongs_to_assoc_for( column )
            assoc_class = Module.const_get assoc.class_name
            SampleModels.samplers[assoc_class].default_creation.instance.id
          else
            1
          end
        else
          raise "No default value for type #{ column.type.inspect }"
      end
    end
    
    def unconfigured_default_for_text(column)
      if !@default and sampler.model_validates_uniqueness_of?(column.name)
        SampleModels.random_word
      else
        "Test #{ column.name }"
      end
    end
  end
  
  module ARClassMethods
    def custom_sample( custom_attrs = {} )
      SampleModels.samplers[self].custom_sample custom_attrs
    end
    
    def default_sample
      SampleModels.samplers[self].default_sample
    end
  end
  
  class ConfigureRecipient
    def initialize( model_class )
      @model_class = model_class
    end
  
    def method_missing( meth, *args )
      if @model_class.column_names.include?( meth.to_s ) or
         SampleModels.samplers[@model_class].belongs_to_assoc_for(meth) or
         @model_class.public_method_defined?("#{meth}=")
        default = if args.size == 1
          args.first
        else
          Proc.new do; yield; end
        end
        SampleModels.configured_defaults[@model_class][meth] = default
      else
        raise(
          NoMethodError, "undefined method `#{meth}' for #{@model_class.name}"
        )
      end
    end
  end
  
  class Creation
    def initialize(sampler)
      @sampler = sampler
    end
    
    def assoc_primary_key_name
      @belongs_to_assoc.primary_key_name if @belongs_to_assoc
    end
    
    def create!
      @instance = begin
        model_class.create! @attributes
      rescue ActiveRecord::RecordInvalid
        $!.to_s =~ /Validation failed: (.*)/
        raise "#{model_class.name} validation failed: #{$1}"
      end
      update_associations
      @instance
    end
    
    def find_by_unique_attributes
      unless @sampler.unique_attributes.empty?
        find_attributes = {}
        @sampler.unique_attributes.each do |name|
          find_attributes[name] = @attributes[name]
        end
        model_class.find(:first, :conditions => find_attributes)
      end
    end
    
    def find_or_create
      @attributes = Attributes.new(
        model_class, self.is_a?(DefaultCreation), @custom_attrs
      )
      find_by_unique_attributes || create!
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
  end
  
  class CustomCreation < Creation
    def initialize(sampler, custom_attrs = {})
      super sampler
      @custom_attrs = custom_attrs
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
    
    def run
      if ds = @sampler.default_instance
        @sampler.belongs_to_associations.each do |assoc|
          recreated_associations = false
          unless assoc.class_name == model_class.name
            assoc_class = Module.const_get assoc.class_name
            if ds.send(assoc.primary_key_name) &&
               !assoc_class.find_by_id(ds.send(assoc.name))
              ds.send(
                "#{assoc.name}=", 
                SampleModels.samplers[assoc_class].default_creation.instance
              )
              recreated_associations = true
            end
          end
          ds.save! if recreated_associations
        end
      else
        set_default
      end
      @instance = @sampler.default_instance
    end
    
    def set_default
      @sampler.default_instance =
          @sampler.create_default_instance_from_proc || find_or_create
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
      SampleModels.samplers[assoc_class].default_creation.instance
    end
  end
  
  class Sampler
    attr_accessor :force_on_create
    attr_reader   :configured_default_attrs, :model_class, :validations
    attr_writer   :default_instance, :default_instance_proc
    
    def initialize(model_class, configured_default_attrs)
      @model_class, @configured_default_attrs =
          model_class, configured_default_attrs
      @validations = Hash.new { |h, field| h[field] = [] }
      @force_on_create = []
    end
    
    def belongs_to_assoc_for( column_or_name )
      if column_or_name.is_a?(String) or column_or_name.is_a?(Symbol)
        belongs_to_associations.detect { |a|
          a.name.to_sym == column_or_name.to_sym
        }
      else
        belongs_to_associations.detect { |a|
          a.primary_key_name == column_or_name.name
        }
      end
    end
    
    def belongs_to_associations
      @model_class.reflect_on_all_associations.select { |assoc|
        assoc.macro == :belongs_to
      }
    end
    
    def clear_default_creation
      @default_creation = nil
    end
    
    def create_default_instance_from_proc
      @default_instance_proc.call if @default_instance_proc
    end
    
    def custom_sample(custom_attrs)
      SampleModels::CustomCreation.new(self, custom_attrs).run
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
    
    def default_sample
      SampleModels.samplers.values.each(&:clear_default_creation)
      default_creation.run
    end
    
    def model_validates_presence_of?(column_name)
      validations[column_name.to_sym].any? { |args|
        args.first == :validates_presence_of
      }
    end
    
    def model_validates_uniqueness_of?(column_name)
      unique_attributes.include?(column_name.to_sym)
    end
    
    def record_validation(*args)
      field = args[1]
      @validations[field] << args
    end
    
    def unconfigured_default_based_on_validations(column)
      unless validations[column.name.to_sym].empty?
        inclusion = validations[column.name.to_sym].detect { |ary|
          ary.first == :validates_inclusion_of
        }
        if inclusion
          inclusion.last[:in].first
        else
          as_email = validations[column.name.to_sym].detect { |ary|
            ary.first == :validates_email_format_of
          }
          if as_email
            "#{SampleModels.random_word}@#{SampleModels.random_word}.com"
          end
        end
      end
    end
    
    def unique_attributes
      validations.
          select { |name, args_array|
            args_array.any? { |args| args.first == :validates_uniqueness_of }
          }.
          map { |name, args_array| name }
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
