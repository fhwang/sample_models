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
        SampleModels.configured_defaults[@domain_class][meth] = args.first
      else
        super
      end
    end
  end
  
  module ARClassMethods
    def custom_sample( custom_attrs = {} )
      default_attrs = default_sample_attrs
      sample = create default_attrs.merge( custom_attrs )
      unless sample.id
        raise "Problem creating #{ self.name }: #{ sample.errors.inspect }"
      end
      sample
    end
    
    def default_sample
      SampleModels.default_samples[self] ||= create( default_sample_attrs )
    end
    
    def default_sample_attrs
      default_atts = {}
      columns_hash.each do |name, column|
        default_att_value = nil
        if cd = SampleModels.configured_defaults[self][name.to_sym]
          default_att_value = cd
        else
          default_att_value = case column.type
            when :binary, :string
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
        default_atts[name.to_sym] = default_att_value
      end
      default_atts
    end
  end
end

if RAILS_ENV == 'test'
  class ActiveRecord::Base
    include SampleModels
  end
end
