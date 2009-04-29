if RAILS_ENV == 'test' # no reason to run this code outside of test mode

module SampleModels
  mattr_accessor :configured_defaults
  self.configured_defaults = Hash.new { |h,k| h[k] = {} }
  mattr_accessor :configured_instances
  self.configured_instances = {}
  mattr_accessor :default_samples
  self.default_samples = {}
  mattr_reader   :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(
      model_class,
      configured_defaults[model_class],
      configured_instances[model_class]
    )
  }

  def self.configure( model_class )
    yield ConfigureRecipient.new( model_class )
  end
    
  def self.default_instance( model_class, &block )
    self.configured_instances[model_class] = Proc.new { block.call }
  end
  
  protected
  
  def self.included( mod )
    mod.extend ARClassMethods
    super
  end
  
  class ConfigureRecipient
    def initialize( model_class )
      @model_class = model_class
    end
  
    def method_missing( meth, *args )
      if @model_class.column_names.include?( meth.to_s )
        default = if args.size == 1
          args.first
        else
          Proc.new do; yield; end
        end
        SampleModels.configured_defaults[@model_class][meth] = default
      else
        super
      end
    end
  end
  
  class Sampler
    def initialize(
          model_class, configured_default_attrs, default_instance_proc
        )
      @model_class, @configured_default_attrs, @default_instance_proc =
          model_class, configured_default_attrs, default_instance_proc
      @validations = Hash.new { |h, field| h[field] = [] }
    end
    
    def record_validation(*args)
      field = args[1]
      @validations[field] << args
    end
    
    def belongs_to_assoc_for( column )
      assocs = @model_class.reflect_on_all_associations
      belongs_to_assocs = assocs.select { |assoc| assoc.macro == :belongs_to }
      belongs_to_assocs.detect { |a| a.primary_key_name == column.name }
    end
    
    def custom(custom_attrs)
      @model_class.create! default_attrs.merge( custom_attrs )
    end
    
    def default
      if ds = @default
        begin
          ds.reload
        rescue ActiveRecord::RecordNotFound
          set_default
        end
      else
        set_default
      end
      @default
    end
    
    def default_attrs
      default_atts = {}
      @model_class.columns_hash.each do |name, column|
        default_att_value = nil
        if @configured_default_attrs.key? name.to_sym
          cd = @configured_default_attrs[name.to_sym]
          cd = cd.call if cd.is_a?( Proc )
          default_att_value = cd
        else
          default_att_value = unconfigured_default_for column
        end
        default_atts[name.to_sym] = default_att_value
      end
      default_atts
    end
    
    def set_default
      if proc = @default_instance_proc
        @default = @default_instance_proc.call
      else
        @default = @model_class.create! default_attrs
      end
    end
    
    def unconfigured_default_for( column )
      udf = unless @validations[column.name.to_sym].empty?
        inclusion = @validations[column.name.to_sym].detect { |ary|
          ary.first == :validates_inclusion_of
        }
        if inclusion
          inclusion.last[:in].first
        end
      end
      udf || case column.type
        when :binary, :string, :text
          "Test #{ column.name }"
        when :boolean
          true
        when :date
          Date.today
        when :datetime
          Time.now.utc
        when :float
          1.0
        when :integer
          unconfigured_default_for_integer( column )
        else
          raise "No default value for type #{ column.type.inspect }"
      end
    end
    
    def unconfigured_default_for_integer( column )
      if assoc = belongs_to_assoc_for( column )
        Module.const_get( assoc.class_name ).default_sample.id
      else
        1
      end
    end
  end
  
  module ARClassMethods
    def custom_sample( custom_attrs = {} )
      SampleModels.samplers[self].custom custom_attrs
    end
    
    def default_sample
      SampleModels.samplers[self].default
    end
  end
end

module ActiveRecord
  class Base
    include SampleModels
  end
  
  module Validations
    module ClassMethods
      define_method "validates_inclusion_of_with_sample_models".to_sym do |*args|
        send "validates_inclusion_of_without_sample_models".to_sym, *args
        SampleModels.samplers[self].record_validation(
          :validates_inclusion_of, *args
        )
      end
      alias_method_chain "validates_inclusion_of".to_sym, :sample_models
    end
  end
end

end
