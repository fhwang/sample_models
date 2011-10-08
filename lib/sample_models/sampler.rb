module SampleModels
  class Sampler
    attr_accessor :before_save, :named_samples, :polymorphic_default_classes
    attr_reader   :defaults
    
    def initialize(model_class)
      @model_class = model_class
      @attribute_sequences = Hash.new { |h,k| h[k] = {} }
      @defaults = HashWithIndifferentAccess.new
      @forced_unique = []
      @named_samples = HashWithIndifferentAccess.new
      @polymorphic_default_classes = HashWithIndifferentAccess.new
    end
    
    def attribute_sequence(pass, column)
      config = HashWithIndifferentAccess.new
      config[:forced_unique] = @forced_unique.include?(column.name)
      if @defaults.member?(column.name)
        config[:default] = @defaults[column.name]
      else
        assoc = model.belongs_to_associations.detect { |a|
          a.foreign_key == column.name
        }
        if assoc && @defaults.member?(assoc.name)
          default_assoc_value = @defaults[assoc.name]
          if default_assoc_value.class.ancestors.include?(ActiveRecord::Base)
            config[:default] = default_assoc_value.id
          elsif default_assoc_value.nil?
            config[:default] = nil
          else
            raise "Not sure how to assign default value #{default_assoc_value.inspect} to #{@model_class.name}##{assoc.name}"
          end
        end
      end
      @attribute_sequences[pass][column.name] ||= begin
        AttributeSequence.build(pass, model, column, config)
      end
    end
    
    def configure(block)
      recipient = ConfigureRecipient.new(self)
      block.call(recipient)
    end
    
    def first_pass_attribute_sequence(column)
      attribute_sequence(:first, column)
    end
    
    def force_unique(attr)
      @forced_unique << attr.to_s
    end

    def model
      SampleModels.models[@model_class]
    end
    
    def sample(*args)
      Creation.new(self, *args).run
    end
    
    def second_pass_attribute_sequence(column)
      attribute_sequence(:second, column)
    end
    
    class ConfigureRecipient
      def initialize(sampler)
        @sampler = sampler
      end
      
      def method_missing(meth, *args, &block)
        if @sampler.model.column_names.include?(meth.to_s)
          Attribute.new(@sampler, meth)
        elsif @sampler.model.belongs_to_association(meth)
          Attribute.new(@sampler, meth)
        elsif @sampler.model.instance_methods.include?(meth.to_s) && 
              @sampler.model.instance_methods.include?("#{meth.to_s}=")
          Attribute.new(@sampler, meth)
        elsif meth.to_s =~ /(.*)_sample$/
          @sampler.named_samples[$1] = args.first
        else
          super
        end
      end

      def before_save(&proc)
        @sampler.before_save = proc
      end
      
      class Attribute
        def initialize(sampler, attribute)
          @sampler, @attribute = sampler, attribute
        end
        
        def default(default)
          if default.blank? and
             @sampler.model.validations(@attribute).any?(&:presence?)
            raise "#{@sampler.model.name} requires #{@attribute} to not be blank"
          else
            @sampler.defaults[@attribute] = default
          end
        end
        
        def default_class(dc)
          @sampler.polymorphic_default_classes[@attribute] = dc
        end
        
        def force_unique
          @sampler.force_unique(@attribute)
        end
      end
    end
  end
end
