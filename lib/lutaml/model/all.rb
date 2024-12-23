module Lutaml
  module Model
    class All
      attr_reader :attribute_tree,
                  :model

      def initialize(model)
        @attribute_tree = []
        @model = model
      end

      def attribute(name, type, options = {})
        options[:parent_all] = self
        @attribute_tree << @model.attribute(name, type, options)
      end

      def group
        raise Lutaml::Model::InvalidAllError.new("Can't define group in all")
      end

      def all
        raise Lutaml::Model::InvalidAllError.new("Nested all definitions are not allowed")
      end

      def choice
        raise Lutaml::Model::InvalidAllError.new("Can't define choice in all")
      end

      def sequence
        raise Lutaml::Model::InvalidAllError.new("Can't define sequence in all")
      end

      def validate_content!(object, validated_attributes = [])
        binding.irb
        attribute_tree.each do |attribute|
          attribute.validate_content!(object, validated_attributes, defined_order)
        end
      end
    end
  end
end
