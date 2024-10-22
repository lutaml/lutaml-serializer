module Lutaml
  module Model
    class MappingRule
      attr_reader :name,
                  :to,
                  :render_nil,
                  :custom_methods,
                  :delegate

      def initialize(
        name,
        to:,
        render_nil: false,
        with: {},
        attribute: false,
        delegate: nil
      )
        @name = name
        @to = to
        @render_nil = render_nil
        @custom_methods = with
        @attribute = attribute
        @delegate = delegate
      end

      alias from name
      alias render_nil? render_nil

      def serialize_attribute(model, element, doc)
        if custom_methods[:to]
          model.send(custom_methods[:to], model, element, doc)
        end
      end

      def to_value_for(model)
        if delegate
          model.public_send(delegate).public_send(to)
        else
          model.public_send(to)
        end
      end

      def serialize(model, parent = nil, doc = nil)
        if custom_methods[:to]
          model.send(custom_methods[:to], model, parent, doc)
        else
          to_value_for(model)
        end
      end

      def deserialize(model, value, attributes, mapper_class = nil)
        if custom_methods[:from]
          mapper_class.new.send(custom_methods[:from], model, value)
        elsif delegate
          if model.public_send(delegate).nil?
            model.public_send(:"#{delegate}=", attributes[delegate].type.new)
          end

          model.public_send(delegate).public_send(:"#{to}=", value)
        else
          model.public_send(:"#{to}=", value)
        end
      end

      def deep_dup
        raise NotImplementedError, "Subclasses must implement `deep_dup`."
      end
    end
  end
end
