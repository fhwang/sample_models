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
      @attribute_sequences[pass][column.name] ||= begin
        AttributeSequence.build(
          pass, model, column, @forced_unique.include?(column.name)
        )
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
          @sampler.defaults[@attribute] = default
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
