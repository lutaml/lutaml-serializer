require "oga"
require "moxml/adapter/oga"
require_relative "xml_document"
require_relative "oga/document"
require_relative "oga/element"
require_relative "builder/oga"

module Lutaml
  module Model
    module XmlAdapter
      class OgaAdapter < XmlDocument
        def self.parse(xml, options = {})
          encoding = options[:encoding] || xml.encoding.to_s
          parsed = Moxml::Adapter::Oga.parse(xml)
          new(parsed.root, encoding)
        end

        def to_xml(options = {})
          return root.to_xml if root.is_a?(Moxml::Element)

          builder_options = {}
          builder_options[:encoding] = if options.key?(:encoding)
                                         options[:encoding] || "UTF-8"
                                       elsif options.key?(:parse_encoding)
                                         options[:parse_encoding]
                                       else
                                         "UTF-8"
                                       end
          builder = Builder::Oga.build(options) do |xml|
            build_element(xml, @root, options)
          end
          xml_data = builder.to_xml.encode!(builder_options[:encoding])
          options[:declaration] ? declaration(options) + xml_data : xml_data
        rescue Encoding::ConverterNotFoundError
          invalid_encoding!(builder_options[:encoding])
        end

        def parse_element(element, klass = nil, format = nil)
          result = Lutaml::Model::MappingHash.new
          result.node = element
          result.item_order = order_of(element)
          process_element(result, element, klass, format)
        end

        def attributes_hash(element)
          result = Lutaml::Model::MappingHash.new

          element.attributes.each do |attr|
            if attr.name == "schemaLocation"
              result["__schema_location"] = {
                namespace: attr.namespace,
                prefix: attr.namespace.prefix,
                schema_location: attr.value,
              }
            else
              result[namespaced_attr_name(attr)] = attr.value
            end
          end

          result
        end

        private

        def name_of(element)
          case element
          when Moxml::Text
            "text"
          when Moxml::Cdata
            "cdata"
          else
            element.name
          end
        end

        def text_of(element)
          element.content
        end

        def namespaced_attr_name(attribute)
          attr_ns = attribute.native.namespace
          if attr_ns.is_a?(::Oga::XML::Namespace)
            prefix = attribute.name == "lang" ? attr_ns.name : attr_ns.uri
            if prefix
              "#{prefix}:#{attribute.name}"
            else
              attribute.name
            end
          else
            attribute.name
          end
        end

        def namespaced_name_of(element)
          case element
          when Moxml::Text
            "text"
          else
            element_ns = element.native.namespace
            if element_ns
              "#{element_ns.uri}:#{element.name}"
            else
              element.name
            end
          end
        end

        def order_of(element)
          element.children.each_with_object([]) do |child, arr|
            arr << name_of(child)
          end
        end

        def build_ordered_element(builder, element, options = {})
          mapper_class = options[:mapper_class] || element.class
          xml_mapping = mapper_class.mappings_for(:xml)
          return xml unless xml_mapping

          attributes = build_attributes(element, xml_mapping).compact

          tag_name = options[:tag_name] || xml_mapping.root_element
          builder.create_and_add_element(tag_name,
                                         attributes: attributes) do |el|
            index_hash = {}
            content = []

            element.element_order.each do |name|
              index_hash[name] ||= -1
              curr_index = index_hash[name] += 1

              element_rule = xml_mapping.find_by_name(name)
              next if element_rule.nil?

              attribute_def = attribute_definition_for(element, element_rule,
                                                       mapper_class: mapper_class)
              value = attribute_value_for(element, element_rule)

              next if element_rule == xml_mapping.content_mapping && element_rule.cdata && name == "text"

              if element_rule == xml_mapping.content_mapping
                text = xml_mapping.content_mapping.serialize(element)
                text = text[curr_index] if text.is_a?(Array)

                next el.add_text(el, text, cdata: element_rule.cdata) if element.mixed?

                content << text
              elsif !value.nil? || element_rule.render_nil?
                value = value[curr_index] if attribute_def.collection?

                add_to_xml(
                  el,
                  element,
                  nil,
                  value,
                  options.merge(
                    attribute: attribute_def,
                    rule: element_rule,
                    mapper_class: mapper_class,
                  ),
                )
              end
            end

            el.add_text(el, content.join)
          end
        end

        def invalid_encoding!(encoding)
          raise Error, "unknown encoding name - #{encoding}"
        end
      end
    end
  end
end
