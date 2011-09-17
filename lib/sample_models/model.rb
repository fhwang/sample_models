module SampleModels
  class Model
    attr_reader :validations_by_attr
    
    def initialize(model_class)
      @model_class = model_class
      @validations_by_attr = Hash.new { |h,k| h[k] = [] }
    end
    
    def associations
      @model_class.reflect_on_all_associations.map { |a| Association.new(a) }
    end
    
    def record_validation(*args)
      type = args.shift
      config = args.extract_options!
      fields = args
      fields.each do |field|
        @validations_by_attr[field] << [type, config]
      end
    end
    
    require 'delegate'
    
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
    end
  end
end
