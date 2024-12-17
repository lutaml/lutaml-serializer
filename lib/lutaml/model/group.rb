module Lutaml
  module Model
    class Group
      attr_reader :attribute_tree,
                  :model

      def initialize(model)
        @attribute_tree = []
        @model = model
      end

      def attribute(_name, _type, _options = {})
        raise Lutaml::Model::InvalidGroupError.new("Attributes can't be defined directly in group")
      end

      def group
        raise Lutaml::Model::InvalidGroupError.new("Nested group definitions are not allowed")
      end

      def choice(&block)
        if @attribute_tree.size >= 1
          raise Lutaml::Model::InvalidGroupError.new("Can't define multiple choices in group")
        end

        process_nested_structure(Choice.new(@model), &block)
      end

      def sequence(&block)
        process_nested_structure(Sequence.new(@model), &block)
      end

      def validate_content!(object, validated_attributes = [], defined_order = [])
        attribute_tree.each do |attribute|
          attribute.validate_content!(object, validated_attributes, defined_order)
        end
      end

      private

      def process_nested_structure(nested_option, &block)
        nested_option.instance_eval(&block)
        @attribute_tree << nested_option
      end
    end
  end
end
