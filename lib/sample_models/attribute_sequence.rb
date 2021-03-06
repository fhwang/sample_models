module SampleModels
  module AttributeSequence
    def self.build(pass, model, column, force_unique, force_email_format)
      sequence = source(pass, model, column, force_email_format)
      validations = model.validations(column.name)
      if (v = validations.detect(&:uniqueness?)) || force_unique
        v ||= Model::Validation.new(:validates_uniqueness_of) 
        sequence = UniquenessFilter.new(model, column, v, sequence)
      end 
      sequence
    end

    def self.source(pass, model, column, force_email_format)
      validations = model.validations(column.name)
      belongs_to_assocs = model.belongs_to_associations
      if force_email_format
        EmailSource.new
      elsif assoc = belongs_to_assocs.detect { |a| a.foreign_key == column.name }
        if validations.any?(&:presence?)
          RequiredBelongsToSource.new(assoc)
        elsif pass == :first
          FirstPassBelongsToSource.new
        else
          SecondPassBelongsToSource.new(model, assoc)
        end
      elsif validations.any?(&:email_format?)
        EmailSource.new
      elsif v = validations.detect(&:inclusion?)
        InclusionSource.new(v)
      elsif v = validations.detect(&:length?)
        LengthSource.new(v)
      else
        SimpleSource.new(column)
      end
    end

    class AbstractSource
      def initialize
        @number = 0
      end

      def next
        @number += 1
        value
      end
    end

    class EmailSource < AbstractSource
      def value
        "john.doe.#{@number}@example.com"
      end
    end

    class FirstPassBelongsToSource < AbstractSource
      def value
        nil
      end
    end

    class InclusionSource < AbstractSource
      def initialize(validation)
        super()
        @validation = validation
      end

      def value
        @validation.config[:in].first
      end
    end
    
    class LengthSource < AbstractSource
      def initialize(validation)
        super()
        @validation = validation
      end

      def value
        minimum = @validation.config[:minimum]
        minimum ||= (
          @validation.config[:within] && @validation.config[:within].begin
        )
        minimum ||= (
          @validation.config[:in] && @validation.config[:in].begin
        )
        minimum ||= 1
        value = 'a' * minimum
        @number.times do
          value = value.succ
        end
        value
      end
    end

    class RequiredBelongsToSource < AbstractSource
      def initialize(assoc)
        super()
        @assoc = assoc
        @previous_instances = {}
      end

      def existing_instance_not_previously_returned
        previous_ids = @previous_instances.values.map(&:id)
        instance = nil
        if previous_ids.empty?
          @assoc.klass.last
        else
          @assoc.klass.last(
            :conditions => ["id not in (?)", previous_ids]
          )
        end
      end

      def set_instance
        instance = existing_instance_not_previously_returned
        instance ||= @assoc.klass.sample
        @previous_instances[@number] = instance
      end

      def value
        if @previous_instances[@number]
          value = @previous_instances[@number]
          begin
            value.reload
            value.id
          rescue ActiveRecord::RecordNotFound
            set_instance
            @previous_instances[@number].id
          end
        else
          set_instance
          @previous_instances[@number].id
        end
      end
    end

    class SecondPassBelongsToSource < AbstractSource
      def initialize(model, assoc)
        super()
        @model, @assoc = model, assoc
      end

      def value
        assoc_klass = @assoc.klass
        unless assoc_klass == @model.ar_class
          record = (assoc_klass.last || assoc_klass.sample)
          record.id
        end
      end
    end

    class SimpleSource < AbstractSource
      def initialize(column)
        super()
        @column = column
      end

      def value
        case @column.type
        when :string, :text
          "#{@column.name} #{@number}"
        when :integer
          @number
        when :datetime
          Time.now.utc - @number.minutes
        when :date
          Date.today - @number
        when :float
          @number.to_f
        end
      end
    end

    class UniquenessFilter
      def initialize(model, column, validation, input)
        @model, @column, @validation, @input =
          model, column, validation, input
      end
      
      def next
        v = @input.next
        unless @validation.config[:allow_nil] && v.nil?
          unless @validation.config[:allow_blank] && v.blank?
            until @model.unique?(@column.name, v)
              v = @input.next
            end
          end
        end
        v
      end

      def value
        self.next
      end
    end
  end
end
