if RAILS_ENV == 'test' # no reason to run this code outside of test mode
  
module SampleModels
  mattr_reader   :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(model_class)
  }

  protected
  
  def self.included( mod )
    mod.extend ARClassMethods
    super
  end
  
  module ARClassMethods
    def sample(attrs={})
      SampleModels.samplers[self].sample attrs
    end
  end
  
  class Model
    def self.belongs_to_associations(model)
      model.reflect_on_all_associations.select { |assoc|
        assoc.macro == :belongs_to
      }
    end
  end
  
  class Sampler
    attr_reader :model_class
    
    def initialize(model_class)
      @model_class = model_class
      @validations_hash = Hash.new { |h, field| h[field] = [] }
    end
    
    def record_validation(*args)
      validation = Validation.new @model_class, *args
      validation.fields.each do |field|
        @validations_hash[field] << validation
      end
    end
    
    def sample(attrs)
      attrs = HashWithIndifferentAccess.new attrs
      @validations_hash.each do |field, validations|
        if attrs[field].nil?
          validations.each do |validation|
            unless validation.allow_nil?
              attrs[field] = validation.satisfying_value
            end
          end
        end
      end
      Model.belongs_to_associations(@model_class).each do |assoc|
        if (value = attrs[assoc.name]) && value.is_a?(Hash)
          attrs[assoc.name] = assoc.klass.sample(value)
        end
      end
      instance = model_class.create! attrs
      proxied_associations = []
      needs_another_save = false
      Model.belongs_to_associations(@model_class).each do |assoc|
        unless instance.send(assoc.name) || attrs.has_key?(assoc.name) ||
               attrs.has_key?(assoc.association_foreign_key)
          needs_another_save = true
          instance.send(
            "#{assoc.name}=", assoc.klass.first || assoc.klass.sample
          )
        end
      end
      instance.save! if needs_another_save
      instance
    end
  end
  
  class Validation
    attr_reader :fields
    
    def initialize(model_class, *args)
      @model_class = model_class
      @type = args.shift
      @config = args.extract_options!
      @fields = args
    end
    
    def allow_nil?
      @config[:allow_nil]
    end
    
    def inclusion?
      @type == :validates_inclusion_of
    end
    
    def satisfying_value
      case @type
      when :validates_email_format_of
        "john.doe@example.com"
      when :validates_inclusion_of
        @config[:in].first
      when :validates_presence_of
        assoc = Model.belongs_to_associations(@model_class).detect { |a|
          a.association_foreign_key.to_sym == @fields.first.to_sym
        }
        if assoc
          assoc.klass.first || assoc.klass.sample
        end
      end
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


=begin
if RAILS_ENV == 'test' # no reason to run this code outside of test mode

require 'delegate'
require "#{File.dirname(__FILE__)}/sample_models/attributes"
require "#{File.dirname(__FILE__)}/sample_models/creation"
require "#{File.dirname(__FILE__)}/sample_models/sampler"
require "#{File.dirname(__FILE__)}/../vendor/ar_query/lib/ar_query"
  
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

  class Validation
    attr_reader :config, :fields
    
    def initialize(*args)
      @type = args.shift
      @config = case @type
        when :validates_email_format_of
          { :message => ' does not appear to be a valid e-mail address', 
            :on => :save, 
            :with => ValidatesEmailFormatOf::Regex }
        when :validates_inclusion_of, :validates_presence_of
          {:on => :save}
        when :validates_uniqueness_of
          { :case_sensitive => true }
      end
      @config.update args.extract_options!
      @fields = args
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
=end
