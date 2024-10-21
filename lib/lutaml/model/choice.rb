module Lutaml
  module Model
    class Choice
      attr_reader :attribute_tree,
                  :model,
                  :min,
                  :max

      def initialize(model, min, max)
        @attribute_tree = []
        @model = model
        @min = min
        @max = max
      end

      def attribute(name, type, options = {})
        options[:parent_choice] = self
        @attribute_tree << @model.attribute(name, type, options)
      end

      def choice(min: 1, max: 1, &block)
        raise StandardError, "Choice range must be positive" unless min.positive? || max.positive?

        @attribute_tree << Choice.new(@model, min, max).tap { |c| c.instance_eval(&block) }
      end

      def validate_content!(object, validated_attributes = [], min = @min, max = @max)
        @attribute_tree.each do |attribute|
          attribute.validate_content!(object, validated_attributes, min, max)
        end

        unless validated_attributes.count.between?(min, max)
          raise Lutaml::Model::OutOfRangeChoiceError.new
        end
      end
    end
  end
end
