module Lutaml
  module Model
    class Sequence
      attr_reader :attribute_tree,
                  :model

      def initialize(model)
        @attribute_tree = []
        @model = model
      end

      def attribute(name, type, options = {})
        options[:parent_sequence] = self
        @model.attribute(name, type, options)
      end

      def sequence(&block)
        @attribute_tree << Sequence.new(@model).tap { |s| s.instance_eval(&block) }
      end

      def map_element(
        name,
        to: nil,
        render_nil: false,
        render_default: false,
        with: {},
        delegate: nil,
        cdata: false,
        namespace: nil,
        prefix: nil
      )
        @attribute_tree << @model.map_element(
          name,
          to: to,
          render_nil: render_nil,
          render_default: render_default,
          with: with,
          delegate: delegate,
          cdata: cdata,
          namespace: namespace,
          prefix: prefix,
        )
      end

      def map_attribute(*)
        raise StandardError,
              "map_attribute is not allowed in sequence"
      end

      def map_content(*)
        raise StandardError,
              "map_content is not allowed in sequence"
      end

      def map_all(*)
        raise StandardError,
              "map_all is not allowed in sequence"
      end

      def validate_content!(element_order, defined_order = [])
        @attribute_tree.each do |rule|
          rule.validate_content!(element_order, defined_order)
        end

        validate_order!(defined_order, element_order)
      end

      def validate_order!(defined_order, element_order)
        element_order.each do |element|
          next unless defined_order.include?(element)

          if defined_order.first == element
            defined_order.shift
          else
            raise Lutaml::Model::IncorrectSequenceError.new
          end
        end
      end
    end
  end
end
