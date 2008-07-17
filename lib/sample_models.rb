module SampleModels
  mattr_accessor :configured_defaults
  self.configured_defaults = Hash.new { |h,k| h[k] = {} }
  mattr_accessor :default_samples
  self.default_samples = {}

  def self.configure( domain_class )
    yield ConfigureRecipient.new( domain_class )
  end
  
  def self.included( mod )
    mod.extend ARClassMethods
    super
  end
  
  class ConfigureRecipient
    def initialize( domain_class )
      @domain_class = domain_class
    end
  
    def method_missing( meth, *args )
      if @domain_class.column_names.include?( meth.to_s )
        default = if args.size == 1
          args.first
        else
          Proc.new do; yield; end
        end
        SampleModels.configured_defaults[@domain_class][meth] = default
      else
        super
      end
    end
  end
  
  module ARClassMethods
    def create_sample( attrs )
      sample = create attrs
      unless sample.id
        raise(
          "Problem creating #{ self.name } sample: #{ sample.errors.inspect }"
        )
      end
      sample
    end
    
    def custom_sample( custom_attrs = {} )
      default_attrs = default_sample_attrs
      create_sample default_attrs.merge( custom_attrs )
    end
    
    def default_sample
      if ds = SampleModels.default_samples[self]
        begin
          ds.reload
        rescue ActiveRecord::RecordNotFound
          SampleModels.default_samples[self] = create_sample(
            default_sample_attrs
          )
        end
      else
        SampleModels.default_samples[self] = create_sample(
          default_sample_attrs
        )
      end
      SampleModels.default_samples[self]
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
          1
        else
          raise "No default value for type #{ column.type.inspect }"
      end
    end
    
    def without_default_sample
      ds = SampleModels.default_samples[self]
      ds.destroy if ds
      yield
      ds.clone.save if ds
    end
  end
end

if RAILS_ENV == 'test'
  class ActiveRecord::Base
    include SampleModels
  end
end
