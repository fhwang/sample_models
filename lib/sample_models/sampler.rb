module SampleModels
  class Sampler
    attr_accessor :before_save, :named_samples, :polymorphic_default_classes
    attr_reader   :defaults
    
    def initialize(model_class)
      @model_class = model_class
      @first_pass_attribute_sequences = {}
      @second_pass_attribute_sequences = {}
      @defaults = HashWithIndifferentAccess.new
      @forced_unique = []
      @named_samples = HashWithIndifferentAccess.new
      @polymorphic_default_classes = HashWithIndifferentAccess.new
    end
    
    def configure(block)
      recipient = ConfigureRecipient.new(self)
      block.call(recipient)
    end
    
    def first_pass_attribute_sequence(column)
      @first_pass_attribute_sequences[column.name] ||= begin
        AttributeSequence.build(
          :first, model, column, @forced_unique.include?(column.name)
        )
      end
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
      @second_pass_attribute_sequences[column.name] ||= begin
        AttributeSequence.build(
          :second, model, column, @forced_unique.include?(column.name)
        )
      end
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
