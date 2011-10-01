require 'delegate'

module SampleModels
  class Model < Delegator
    attr_reader :ar_class
    
    def initialize(ar_class)
      @ar_class = ar_class
      @validations = Hash.new { |h,k| h[k] = [] }
    end
    
    def __getobj__
      @ar_class
    end
    
    def associations
      @ar_class.reflect_on_all_associations.map { |a| Association.new(a) }
    end
    
    def belongs_to_association(name)
      belongs_to_associations.detect { |a| a.name.to_s == name.to_s }
    end
    
    def belongs_to_associations
      associations.select { |a| a.belongs_to? }
    end
    
    def has_many_associations
      associations.select { |a| a.has_many? }
    end
    
    def record_validation(*args)
      type = args.shift
      config = args.extract_options!
      fields = args
      fields.each do |field|
        @validations[field.to_s] << Validation.new(type, config)
      end
    end
    
    def unique?(field, value)
      @ar_class.count(:conditions => {field => value}) == 0
    end
    
    def validated_attr_accessors
      @validations.keys.select { |key|
        columns.none? { |column| column.name.to_s == key.to_s }
      }
    end
    
    def validations(name)
      @validations[name.to_s]
    end
    
    class Association < Delegator
      def initialize(assoc)
        @assoc = assoc
      end
      
      def __getobj__
        @assoc
      end
      
      def belongs_to?
        @assoc.macro == :belongs_to
      end
      
      def foreign_key
        if @assoc.respond_to?(:foreign_key)
          @assoc.foreign_key
        else
          @assoc.primary_key_name
        end
      end
      
      def has_many?
        @assoc.macro == :has_many
      end
      
      def polymorphic?
        @assoc.options[:polymorphic]
      end
    end
    
    class Validation
      attr_reader :config, :type
      
      def initialize(type, config = {})
        @type, @config = type, config
      end
      
      def email_format?
        @type == :validates_email_format_of
      end
      
      def inclusion?
        @type == :validates_inclusion_of
      end
      
      def presence?
        @type == :validates_presence_of
      end
    end
  end
end
