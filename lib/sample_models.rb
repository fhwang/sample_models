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
  
  def self.random_word(length = 20)
    letters = 'abcdefghijklmnopqrstuvwxyz'.split //
    (1..length).to_a.map { letters[rand(letters.size)] }.join( '' )
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
  
  class Creation
    def initialize(model_class)
      @model_class = model_class
    end
    
    def belongs_to_assoc_for( column )
      assocs = @model_class.reflect_on_all_associations
      belongs_to_assocs = assocs.select { |assoc| assoc.macro == :belongs_to }
      belongs_to_assocs.detect { |a| a.primary_key_name == column.name }
    end
    
    def create!(atts)
      begin
        @model_class.create! atts
      rescue ActiveRecord::RecordInvalid
        $!.to_s =~ /Validation failed: (.*)/
        raise "#{@model_class.name} validation failed: #{$1}"
      end
    end
    
    def default_attrs
      default_atts = {}
      @model_class.columns_hash.each do |name, column|
        default_att_value = nil
        if sampler.configured_default_attrs.key? name.to_sym
          cd = sampler.configured_default_attrs[name.to_sym]
          cd = cd.call if cd.is_a?( Proc )
          default_att_value = cd
        else
          default_att_value = unconfigured_default_for column
        end
        default_atts[name.to_sym] = default_att_value
      end
      default_atts
    end
    
    def sampler
      SampleModels.samplers[@model_class]
    end
    
    def unconfigured_default_based_on_validations(column)
      unless sampler.validations[column.name.to_sym].empty?
        inclusion = sampler.validations[column.name.to_sym].detect { |ary|
          ary.first == :validates_inclusion_of
        }
        if inclusion
          inclusion.last[:in].first
        else
          as_email = sampler.validations[column.name.to_sym].detect { |ary|
            ary.first == :validates_email_format_of
          }
          if as_email
            "#{SampleModels.random_word}@#{SampleModels.random_word}.com"
          end
        end
      end
    end
    
    def unconfigured_default_for( column )
      udf = unconfigured_default_based_on_validations column
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
        unless assoc.class_name == @model_class.name
          Module.const_get(assoc.class_name).default_sample.id
        end
      else
        1
      end
    end
  end
  
  class CustomCreation < Creation
    def initialize(model_class, custom_attrs = {})
      super model_class
      @custom_attrs = custom_attrs
    end
    
    def run
      create! default_attrs.merge( @custom_attrs )
    end
  end
  
  class DefaultCreation < Creation
    def run
      if ds = sampler.default_instance
        begin
          ds.reload
        rescue ActiveRecord::RecordNotFound
          set_default
        end
      else
        set_default
      end
      sampler.default_instance
    end
    
    def set_default
      if proc = sampler.default_instance_proc
        default_instance = proc.call
      else
        default_instance = create! default_attrs
      end
      sampler.default_instance = default_instance
    end
  end
  
  class Sampler
    attr_accessor :default_instance
    attr_reader :configured_default_attrs, :default_instance_proc, :validations
    
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
  end
  
  module ARClassMethods
    def custom_sample( custom_attrs = {} )
      SampleModels::CustomCreation.new(self, custom_attrs).run
    end
    
    def default_sample
      SampleModels::DefaultCreation.new(self).run
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
       :validates_inclusion_of].each do |validation|
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

end
