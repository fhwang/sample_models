module SampleModels
  mattr_accessor :configured_defaults
  self.configured_defaults = Hash.new { |h,k| h[k] = {} }
  mattr_accessor :configured_instances
  self.configured_instances = {}
  mattr_accessor :default_samples
  self.default_samples = {}

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
  
  module ARClassMethods
    def custom_sample( custom_attrs = {} )
      default_attrs = default_sample_attrs
      create_sample default_attrs.merge( custom_attrs )
    end
    
    def default_sample
      if ds = SampleModels.default_samples[self]
        begin
          ds.reload
        rescue ActiveRecord::RecordNotFound
          set_default_sample
        end
      else
        set_default_sample
      end
      SampleModels.default_samples[self]
    end
    
    def without_default_sample
      ds = SampleModels.default_samples[self]
      ds.destroy if ds
      yield
      ds.clone.save if ds
    end
    
    protected
    
    def belongs_to_assoc_for( column )
      belongs_to_assocs = reflect_on_all_associations.select { |assoc|
        assoc.macro == :belongs_to
      }
      belongs_to_assocs.detect { |a| a.primary_key_name == column.name }
    end
    
    def create_sample( attrs )
      sample = create attrs
      unless sample.id
        raise(
          "Problem creating #{ self.name } sample: #{ sample.errors.inspect }"
        )
      end
      sample
    end
    
    def default_sample_attrs
      default_atts = {}
      columns_hash.each do |name, column|
        default_att_value = nil
        if SampleModels.configured_defaults[self].key? name.to_sym
          cd = SampleModels.configured_defaults[self][name.to_sym]
          cd = cd.call if cd.is_a?( Proc )
          default_att_value = cd
        else
          default_att_value = unconfigured_default_for column
        end
        default_atts[name.to_sym] = default_att_value
      end
      default_atts
    end
    
    def set_default_sample
      if proc = SampleModels.configured_instances[self]
        SampleModels.default_samples[self] = proc.call
      else
        SampleModels.default_samples[self] = create_sample(
          default_sample_attrs
        )
      end
    end
    
    def unconfigured_default_for( column )
      case column.type
        when :binary, :string, :text
          "Test #{ column.name }"
        when :boolean
          true
        when :date
          Date.today
        when :datetime
          Time.now.utc
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
end

if RAILS_ENV == 'test'
  class ActiveRecord::Base
    include SampleModels
  end
end
