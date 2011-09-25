module SampleModels
  class Sampler
    attr_reader :defaults
    
    def initialize(model_class)
      @model_class = model_class
      @first_pass_attribute_sequences = {}
      @second_pass_attribute_sequences = {}
      @defaults = HashWithIndifferentAccess.new
      @forced_unique = []
    end
    
    def configure(block)
      recipient = ConfigureRecipient.new(self)
      block.call(recipient)
    end
    
    def first_pass_attribute_sequence(column)
      unless @first_pass_attribute_sequences[column.name]
        input = FirstPassBaseAttributeSequence.new(model, column)
        model.validations(column).each do |validation|
          sequence_name = validation.type.to_s.camelize + 'AttributeSequence'
          if SampleModels.const_defined?(sequence_name)
            sequence_class = SampleModels.const_get(sequence_name)
            input = sequence_class.new(model, column, validation, input)
          end
        end
        if @forced_unique.include?(column.name)
          input = ValidatesUniquenessOfAttributeSequence.new(
            model, column, Model::Validation.new(:validates_uniqueness_of), 
            input
          )
        end
        @first_pass_attribute_sequences[column.name] = input
      end
      @first_pass_attribute_sequences[column.name]
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
      unless @second_pass_attribute_sequences[column.name]
        input = SecondPassBaseAttributeSequence.new(model, column)
        model.validations(column).each do |validation|
          sequence_name = validation.type.to_s.camelize + 'AttributeSequence'
          if SampleModels.const_defined?(sequence_name)
            sequence_class = SampleModels.const_get(sequence_name)
            input = sequence_class.new(model, column, validation, input)
          end
        end
        if @forced_unique.include?(column.name)
          input = ValidatesUniquenessOfAttributeSequence.new(
            model, column, Model::Validation.new(:validates_uniqueness_of), input
          )
        end
        @second_pass_attribute_sequences[column.name] = input
      end
      @second_pass_attribute_sequences[column.name]
    end
    
    class ConfigureRecipient
      def initialize(sampler)
        @sampler = sampler
      end
      
      def method_missing(meth, *args, &block)
        if @sampler.model.column_names.include?(meth.to_s)
          Attribute.new(@sampler, meth)
        elsif @sampler.model.belongs_to_associations.any? { |a|
            a.name == meth
        }
          Attribute.new(@sampler, meth)
        elsif meth.to_s =~ /(.*)_sample$/
        else
          super
        end
      end

      def before_save
      end
      
      class Attribute
        def initialize(sampler, attribute)
          @sampler, @attribute = sampler, attribute
        end
        
        def default(default)
          @sampler.defaults[@attribute] = default
        end
        
        def force_unique
          @sampler.force_unique(@attribute)
        end
      end
    end
  end
end
