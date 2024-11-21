require "spec_helper"
require "lutaml/model/schema"
require "lutaml/xsd"
require "tmpdir"

RSpec.describe Lutaml::Model::Schema::XmlCompiler do
  describe ".to_models" do
    context "with valid xml schema, it should generate the models" do
      let(:valid_value_xml_example) do
        <<~VALID_XML_EXAMPLE
          <CT_MathTest>
            <MathTest val="1"/>
            <MathTest1 val="1"/>
          </CT_MathTest>
        VALID_XML_EXAMPLE
      end

      let(:invalid_value_xml_example) do
        <<~INVALID_XML_EXAMPLE
          <CT_MathTest>
            <MathTest val="0"/>
            <MathTest1 val="-3"/>
          </CT_MathTest>
        INVALID_XML_EXAMPLE
      end

      Dir.mktmpdir do |dir|
        it "generates the models, requires them, and tests them with valid and invalid xml" do
          described_class.to_models(File.read("spec/fixtures/xml/test_schema.xsd"), output_dir: dir)
          expect(File).to exist("#{dir}/ct_math_test.rb")
          expect(File).to exist("#{dir}/st_integer255.rb")
          expect(File).to exist("#{dir}/long.rb")
          Dir.each_child(dir) { |child| require_relative File.expand_path("#{dir}/#{child}") }
          expect(defined?(CTMathTest)).to eq("constant")
          expect(CTMathTest.from_xml(valid_value_xml_example).to_xml).to be_equivalent_to(valid_value_xml_example)
          expect { CTMathTest.from_xml(invalid_value_xml_example) }.to raise_error(Lutaml::Model::Type::InvalidValueError)
        end
      end
    end
  end

  describe "structure setup methods" do
    describe ".as_models" do
      context "when the XML adapter is not set" do
        before do
          Lutaml::Model::Config.xml_adapter_type = :ox
        end

        after do
          Lutaml::Model::Config.xml_adapter_type = :nokogiri
        end

        it "raises an error" do
          expect { described_class.send(:as_models, '<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>') }.to raise_error(Lutaml::Model::Error)
        end
      end

      context "when the XML adapter is set and schema is given" do
        let(:schema) { '<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>' }

        it "initializes the instance variables with empty MappingHash" do
          described_class.send(:as_models, schema)
          variables = %i[@elements @attributes @group_types @simple_types @complex_types @attribute_groups]
          variables.each do |variable|
            instance_variable = described_class.instance_variable_get(variable)
            expect(instance_variable).to be_a(Lutaml::Model::MappingHash)
            expect(instance_variable).to be_empty
          end
        end

        it "parses the schema and populates the instance variables" do
          expect(described_class.send(:as_models, schema)).to be_nil
        end
      end
    end

    describe ".schema_to_models" do
      context "when given schema element is empty" do
        let(:schema) { [] }

        it "returns nil if schema array is empty" do
          expect(described_class.send(:schema_to_models, schema)).to be_nil
        end

        it "returns nil if schema array contains empty schema instance" do
          schema << Lutaml::Xsd::Schema.new
          expect(described_class.send(:schema_to_models, schema)).to be_nil
        end
      end

      context "when given schema contains all the elements" do
        before do
          variables.each_key do |key|
            described_class.instance_variable_set(:"@#{key}", to_mapping_hash({}))
          end
        end

        after do
          variables.each_key do |key|
            described_class.instance_variable_set(:"@#{key}", nil)
          end
        end

        let(:schema) do
          Lutaml::Xsd.parse(<<~XSD)
            <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
              <xsd:element name="test_element"/>
              <xsd:attribute name="test_attribute" type="xsd:string"/>
              <xsd:group name="test_group"/>
              <xsd:simpleType name="test_simple_type"/>
              <xsd:complexType name="test_complex_type"/>
              <xsd:attributeGroup name="test_attribute_group"/>
            </xsd:schema>
          XSD
        end

        let(:variables) do
          {
            elements: { "test_element" => { element_name: "test_element", type_name: nil } },
            attributes: { "test_attribute" => { name: "test_attribute", base_class: "xsd:string" } },
            group_types: { "test_group" => {} },
            simple_types: { "test_simple_type" => {} },
            complex_types: { "test_complex_type" => {} },
            attribute_groups: { "test_attribute_group" => {} },
          }
        end

        it "initializes the instance variables with empty MappingHash" do
          described_class.send(:schema_to_models, [schema])
          variables.each do |variable, expected_value|
            instance_variable = described_class.instance_variable_get(:"@#{variable}")
            expect(instance_variable).to be_a(Lutaml::Model::MappingHash)
            expect(instance_variable).to eql(expected_value)
          end
        end
      end
    end

    describe ".setup_simple_type" do
      context "when given simple_type contains restriction and union" do
        let(:simple_type) do
          Lutaml::Xsd::SimpleType.new.tap do |st|
            st.restriction = Lutaml::Xsd::RestrictionSimpleType.new(base: "test_base")
            st.union = Lutaml::Xsd::Union.new(member_types: "")
          end
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_simple_type, simple_type)).to eql({ base_class: "test_base", union: [] })
        end
      end

      context "when simple_type contains nothing" do
        let(:simple_type) { Lutaml::Xsd::SimpleType.new }

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_simple_type, simple_type)).to eql({})
        end
      end
    end

    describe ".restriction_content" do
      context "when given restriction contains max_length, min_length, min_inclusive, max_inclusive, length" do
        let(:restriction) do
          Lutaml::Xsd::RestrictionSimpleType.new.tap do |r|
            r.max_length = [Lutaml::Xsd::MaxLength.new(value: "10")]
            r.min_length = [Lutaml::Xsd::MinLength.new(value: "1")]
            r.min_inclusive = [Lutaml::Xsd::MinInclusive.new(value: "1")]
            r.max_inclusive = [Lutaml::Xsd::MaxInclusive.new(value: "10")]
            r.length = [Lutaml::Xsd::Length.new(value: "10")]
          end
        end

        it "initializes the instance variables with empty MappingHash" do
          described_class.send(:restriction_content, hash = {}, restriction)
          expect(hash).to eql({ max_length: 10, min_length: 1, min_inclusive: "1", max_inclusive: "10", length: [{ value: 10 }] })
        end
      end

      context "when restriction contains nothing" do
        let(:restriction) { Lutaml::Xsd::RestrictionSimpleType.new }

        it "initializes the instance variables with empty MappingHash" do
          described_class.send(:restriction_content, hash = {}, restriction)
          expect(hash).to be_empty
        end
      end
    end

    describe ".restriction_length" do
      context "when given restriction contains max_length, min_length, min_inclusive, max_inclusive, length" do
        let(:lengths) do
          [
            Lutaml::Xsd::Length.new(value: "10", fixed: true),
            Lutaml::Xsd::Length.new(value: "1"),
            Lutaml::Xsd::Length.new(value: "1", fixed: true),
            Lutaml::Xsd::Length.new(value: "10"),
            Lutaml::Xsd::Length.new(value: "10", fixed: true),
          ]
        end

        let(:expected_content) do
          [
            { value: 10, fixed: true },
            { value: 1 },
            { value: 1, fixed: true },
            { value: 10 },
            { value: 10, fixed: true },
          ]
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:restriction_length, lengths)).to eql(expected_content)
        end
      end

      context "when restriction contains nothing" do
        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:restriction_length, [])).to be_empty
        end
      end
    end

    describe ".setup_complex_type" do
      context "when given complex_type contains attribute, sequence, choice, complex_content, attribute_group, group, simple_content" do
        let(:complex_type) do
          Lutaml::Xsd::ComplexType.new.tap do |ct|
            ct.attribute = [Lutaml::Xsd::Attribute.new(type: "test_attribute", name: "test_attribute1")]
            ct.sequence = [Lutaml::Xsd::Sequence.new(name: "test_sequence")]
            ct.choice = [Lutaml::Xsd::Choice.new(name: "test_choice")]
            ct.complex_content = [Lutaml::Xsd::ComplexContent.new(name: "test_complex_content")]
            ct.attribute_group = [Lutaml::Xsd::AttributeGroup.new(name: "test_attribute_group")]
            ct.group = [Lutaml::Xsd::Group.new(name: "test_group")]
            ct.simple_content = [Lutaml::Xsd::SimpleContent.new(name: "test_simple_content")]
            ct.element_order = ["attribute", "sequence", "choice", "complex_content", "attribute_group", "group", "simple_content"]
          end
        end

        let(:expected_hash) do
          {
            attributes: [{ name: "test_attribute1", base_class: "test_attribute" }],
            sequence: {},
            choice: {},
            complex_content: {},
            attribute_groups: [{}],
            group: {},
            simple_content: nil,
          }
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_complex_type, complex_type)).to eql(expected_hash)
        end
      end

      context "when restriction contains nothing" do
        let(:complex_type) do
          Lutaml::Xsd::ComplexType.new.tap do |ct|
            ct.element_order = []
          end
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_complex_type, complex_type)).to be_empty
        end
      end
    end

    describe ".setup_simple_content" do
      context "when given complex_type contains extension" do
        let(:complex_type) do
          Lutaml::Xsd::SimpleContent.new.tap do |ct|
            ct.extension = Lutaml::Xsd::ExtensionSimpleContent.new(base: "test_extension")
            ct.element_order = ["extension"]
          end
        end

        let(:expected_hash) { { extension_base: "test_extension" } }

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_simple_content, complex_type)).to eql(expected_hash)
        end
      end

      context "when complex_type contains restriction" do
        let(:complex_type) do
          Lutaml::Xsd::SimpleContent.new.tap do |ct|
            ct.restriction = Lutaml::Xsd::RestrictionSimpleContent.new(base: "test_restriction")
            ct.element_order = ["restriction"]
          end
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_simple_content, complex_type)).to eql({ base_class: "test_restriction" })
        end
      end
    end

    describe ".setup_sequence" do
      context "when given sequence contains sequence, element, choice, group" do
        let(:sequence) do
          Lutaml::Xsd::Sequence.new.tap do |ct|
            ct.sequence = [Lutaml::Xsd::Sequence.new(name: "test_sequence")]
            ct.element = [
              Lutaml::Xsd::Element.new(name: "test_element"),
              Lutaml::Xsd::Element.new(ref: "test_ref"),
            ]
            ct.choice = [Lutaml::Xsd::Choice.new(name: "test_choice")]
            ct.group = [
              Lutaml::Xsd::Group.new(name: "test_group"),
              Lutaml::Xsd::Group.new(ref: "test_ref"),
            ]
            ct.element_order = ["sequence", "group", "element", "choice", "element", "group"]
          end
        end

        let(:expected_hash) do
          {
            sequences: [{}],
            elements: [{ element_name: "test_element", type_name: nil }, { ref_class: "test_ref" }],
            choice: [{}],
            groups: [{}, { ref_class: "test_ref" }],
          }
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_sequence, sequence)).to eql(expected_hash)
        end
      end

      context "when sequence contains nothing" do
        let(:sequence) do
          Lutaml::Xsd::Sequence.new.tap do |ct|
            ct.element_order = []
          end
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_sequence, sequence)).to be_empty
        end
      end
    end

    describe ".setup_group_type" do
      context "when given group contains sequence, choice" do
        let(:group) do
          Lutaml::Xsd::Group.new.tap do |ct|
            ct.sequence = [Lutaml::Xsd::Sequence.new(name: "test_sequence")]
            ct.choice = [Lutaml::Xsd::Choice.new(name: "test_choice")]
            ct.element_order = ["sequence", "choice"]
          end
        end

        let(:expected_hash) { { sequence: {}, choice: {} } }

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_group_type, group)).to eql(expected_hash)
        end
      end

      context "when sequence contains nothing" do
        let(:group) do
          Lutaml::Xsd::Group.new.tap do |ct|
            ct.element_order = []
          end
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_group_type, group)).to be_empty
        end
      end
    end

    describe ".setup_choice" do
      context "when given choice contains sequence, choice" do
        let(:choice) do
          Lutaml::Xsd::Choice.new.tap do |ct|
            ct.element = [Lutaml::Xsd::Element.new(name: "test_element")]
            ct.sequence = [Lutaml::Xsd::Sequence.new(name: "test_sequence")]
            ct.choice = [Lutaml::Xsd::Choice.new(name: "test_choice")]
            ct.group = [Lutaml::Xsd::Group.new(name: "test_group")]
            ct.element_order = ["sequence", "choice", "group", "element"]
          end
        end

        let(:expected_hash) { { sequence: {}, choice: {}, group: {}, "test_element" => { element_name: "test_element", type_name: nil } } }

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_choice, choice)).to eql(expected_hash)
        end
      end

      context "when choice contains nothing" do
        let(:choice) do
          Lutaml::Xsd::Choice.new.tap do |ct|
            ct.element_order = []
          end
        end

        it "initializes the instance variables with empty MappingHash" do
          expect(described_class.send(:setup_choice, choice)).to be_empty
        end
      end
    end

    describe ".setup_union" do
      context "when given union contains member_types" do
        before do
          described_class.instance_variable_set(:@simple_types, simple_types)
        end

        after do
          described_class.instance_variable_set(:@simple_types, nil)
        end

        let(:simple_types) do
          {
            "test_member_type" => { name: "test_member_type" },
            "test_member_type1" => { name: "test_member_type1" },
          }
        end

        let(:union) do
          Lutaml::Xsd::Union.new.tap do |ct|
            ct.member_types = "test_member_type test_member_type1"
          end
        end

        let(:expected_hash) { [{ name: "test_member_type" }, { name: "test_member_type1" }] }

        it "returns the expected hash" do
          expect(described_class.send(:setup_union, union)).to eql(expected_hash)
        end
      end

      context "when union contains nothing" do
        let(:union) { Lutaml::Xsd::Union.new }

        it "returns the empty hash" do
          expect(described_class.send(:setup_union, union)).to be_empty
        end
      end
    end

    describe ".setup_attribute" do
      context "when given attribute contains name and type" do
        let(:attribute) do
          Lutaml::Xsd::Attribute.new.tap do |attr|
            attr.name = "test_name"
            attr.type = "test_type"
          end
        end

        let(:expected_hash) { { name: "test_name", base_class: "test_type" } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_attribute, attribute)).to eql(expected_hash)
        end
      end

      context "when given attribute contains ref" do
        let(:attribute) do
          Lutaml::Xsd::Attribute.new.tap do |attr|
            attr.ref = "test_ref"
          end
        end

        let(:expected_hash) { { ref_class: "test_ref" } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_attribute, attribute)).to eql(expected_hash)
        end
      end

      context "when attribute contains nothing" do
        let(:attribute) { Lutaml::Xsd::Attribute.new }
        let(:expected_hash) { { name: nil, base_class: nil } }

        it "returns the empty hash" do
          expect(described_class.send(:setup_attribute, attribute)).to eql(expected_hash)
        end
      end
    end

    describe ".setup_attribute_groups" do
      context "when given attribute_group contains attribute and attribute_group" do
        let(:attribute_group) do
          Lutaml::Xsd::AttributeGroup.new.tap do |attr_group|
            attr_group.attribute = [Lutaml::Xsd::Attribute.new(name: "test_name", type: "test_type")]
            attr_group.attribute_group = [Lutaml::Xsd::AttributeGroup.new(name: "test_name", type: "test_type")]
            attr_group.element_order = ["attribute", "attribute_group"]
          end
        end

        let(:expected_hash) { { attributes: [{ name: "test_name", base_class: "test_type" }], attribute_groups: [{}] } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_attribute_groups, attribute_group)).to eql(expected_hash)
        end
      end

      context "when given attribute_group contains ref" do
        let(:attribute_group) do
          Lutaml::Xsd::AttributeGroup.new.tap do |attr_group|
            attr_group.ref = "test_ref"
          end
        end

        let(:expected_hash) { { ref_class: "test_ref" } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_attribute_groups, attribute_group)).to eql(expected_hash)
        end
      end

      context "when attribute_group contains nothing" do
        let(:attribute_group) { Lutaml::Xsd::AttributeGroup.new }

        it "returns the empty hash" do
          expect(described_class.send(:setup_attribute_groups, attribute_group)).to be_empty
        end
      end
    end

    describe ".create_mapping_hash" do
      context "when given value is a string and hash_key is :class_name" do
        let(:value) { "test_value" }
        let(:expected_hash) { { class_name: "test_value" } }

        it "returns the expected hash" do
          expect(described_class.send(:create_mapping_hash, value, hash_key: :class_name)).to eql(expected_hash)
        end
      end

      context "when given value is a string and hash_key is :element_name" do
        let(:value) { "test_value" }
        let(:expected_hash) { { element_name: "test_value" } }

        it "returns the expected hash" do
          expect(described_class.send(:create_mapping_hash, value, hash_key: :element_name)).to eql(expected_hash)
        end
      end

      context "when given value is a array and hash_key is :ref_class" do
        let(:value) { ["test_value"] }
        let(:expected_hash) { { ref_class: ["test_value"] } }

        it "returns the expected hash" do
          expect(described_class.send(:create_mapping_hash, value, hash_key: :ref_class)).to eql(expected_hash)
        end
      end

      context "when given value is a string and hash_key is not given" do
        let(:value) { "test_value" }
        let(:expected_hash) { { class_name: "test_value" } }

        it "returns the expected hash" do
          expect(described_class.send(:create_mapping_hash, value)).to eql(expected_hash)
        end
      end
    end

    describe ".setup_element" do
      before do
        described_class.instance_variable_set(:@complex_types, complex_types)
      end

      after do
        described_class.instance_variable_set(:@complex_types, nil)
      end

      let(:complex_types) { { "test_complex_type" => {} } }

      context "when given element contains ref" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.ref = "test_ref"
          end
        end

        let(:expected_hash) { { ref_class: "test_ref" } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_element, element)).to eql(expected_hash)
        end
      end

      context "when given element contains ref with other attributes/elements" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.ref = "test_ref"
            element.type = "test_type"
            element.name = "test_name"
            element.min_occurs = 0
            element.max_occurs = 1
            element.complex_type = Lutaml::Xsd::ComplexType.new(name: "test_complex_type")
            element.element_order = ["complex_type"]
          end
        end

        let(:expected_hash) { { ref_class: "test_ref" } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_element, element)).to eql(expected_hash)
        end
      end

      context "when given element contains type, name and min/max_occurs" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.type = "test_type"
            element.name = "test_name"
            element.min_occurs = 0
            element.max_occurs = 1
          end
        end

        let(:expected_hash) { { type_name: "test_type", element_name: "test_name", arguments: { min_occurs: "0", max_occurs: "1" } } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_element, element)).to eql(expected_hash)
        end
      end

      context "when given element contains name, type, and complex_type and no min/max_occurs" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.type = "test_type"
            element.name = "test_name"
            element.complex_type = Lutaml::Xsd::ComplexType.new(name: "test_complex_type")
            element.element_order = ["complex_type"]
          end
        end

        let(:expected_hash) { { type_name: "test_type", element_name: "test_name", complex_type: {} } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_element, element)).to eql(expected_hash)
        end
      end

      context "when given element contains nothing" do
        let(:element) { Lutaml::Xsd::Element.new }
        let(:expected_hash) { { type_name: nil, element_name: nil } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_element, element)).to eql(expected_hash)
        end
      end
    end

    describe ".setup_restriction" do
      context "when given restriction contains base and pattern" do
        let(:restriction) do
          Lutaml::Xsd::RestrictionSimpleType.new.tap do |restriction|
            restriction.base = "test_base"
            restriction.pattern = [
              Lutaml::Xsd::Pattern.new(value: /test_pattern/),
              Lutaml::Xsd::Pattern.new(value: /test_pattern1/),
            ]
            restriction.enumeration = [
              Lutaml::Xsd::Enumeration.new(value: "test_value"),
              Lutaml::Xsd::Enumeration.new(value: "test_value1"),
            ]
          end
        end

        let(:expected_hash) { { base_class: "test_base", pattern: "((?-mix:test_pattern))|((?-mix:test_pattern1))", values: ["test_value", "test_value1"] } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_restriction, restriction, {})).to eql(expected_hash)
        end
      end

      context "when given restriction contains nothing" do
        let(:restriction) { Lutaml::Xsd::RestrictionSimpleType.new }

        it "returns the expected hash" do
          expect(described_class.send(:setup_restriction, restriction, {})).to eql({ base_class: nil })
        end
      end
    end

    describe ".restriction_patterns" do
      context "when given patterns are not empty" do
        let(:patterns) do
          [
            Lutaml::Xsd::Pattern.new(value: /test_pattern/),
            Lutaml::Xsd::Pattern.new(value: /test_pattern1/),
          ]
        end

        let(:expected_hash) { { pattern: "((?-mix:test_pattern))|((?-mix:test_pattern1))" } }

        it "returns the expected hash" do
          expect(described_class.send(:restriction_patterns, patterns, {})).to eql(expected_hash)
        end
      end

      context "when given patterns are empty" do
        let(:patterns) { [] }

        it "returns the expected hash" do
          expect(described_class.send(:restriction_patterns, patterns, {})).to be_nil
        end
      end
    end

    describe ".setup_complex_content" do
      context "when given complex_content contains extension with mixed attribute" do
        let(:complex_content) do
          Lutaml::Xsd::ComplexContent.new.tap do |complex_content|
            complex_content.mixed = true
            complex_content.extension = Lutaml::Xsd::ExtensionComplexContent.new(base: "test_base")
          end
        end

        let(:expected_hash) { { mixed: true, extension: { extension_base: "test_base" } } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_complex_content, complex_content)).to eql(expected_hash)
        end
      end

      context "when given complex_content contains restriction" do
        let(:complex_content) do
          Lutaml::Xsd::ComplexContent.new.tap do |complex_content|
            complex_content.restriction = Lutaml::Xsd::RestrictionComplexContent.new(base: "test_base")
          end
        end

        let(:expected_hash) { { base_class: "test_base" } }

        it "returns the expected hash" do
          expect(described_class.send(:setup_complex_content, complex_content)).to eql(expected_hash)
        end
      end
    end

    describe ".setup_extension" do
      context "when given extension contains attributes" do
        let(:extension) do
          Lutaml::Xsd::ExtensionComplexContent.new.tap do |extension|
            extension.base = "test_base"
            extension.attribute = [
              Lutaml::Xsd::Attribute.new(type: "ST_Attr1", name: "Attr1", default: "1"),
              Lutaml::Xsd::Attribute.new(type: "ST_Attr2", name: "Attr2", default: "2"),
            ]
            extension.sequence = Lutaml::Xsd::Sequence.new
            extension.choice = Lutaml::Xsd::Choice.new
            extension.element_order = ["attribute", "sequence", "choice", "attribute"]
          end
        end

        let(:expected_hash) do
          {
            extension_base: "test_base",
            attributes: [{ base_class: "ST_Attr1", name: "Attr1", default: "1" }, { base_class: "ST_Attr2", name: "Attr2", default: "2" }],
            sequence: {},
            choice: {},
          }
        end

        it "returns the expected hash" do
          expect(described_class.send(:setup_extension, extension)).to eql(expected_hash)
        end
      end

      context "when given extension contains nothing" do
        let(:extension) { Lutaml::Xsd::ExtensionComplexContent.new }

        it "returns the expected hash" do
          expect(described_class.send(:setup_extension, extension)).to eql({ extension_base: nil })
        end
      end
    end

    describe ".element_arguments" do
      context "when given element contains min_occurs and max_occurs" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.min_occurs = "0"
            element.max_occurs = "1"
          end
        end

        let(:expected_hash) { { min_occurs: "0", max_occurs: "1" } }

        it "returns the expected hash" do
          expect(described_class.send(:element_arguments, element, {})).to eql(expected_hash)
        end
      end

      context "when given element contains nothing" do
        let(:element) { Lutaml::Xsd::Element.new }

        it "returns the expected hash" do
          expect(described_class.send(:element_arguments, element, {})).to be_empty
        end
      end
    end

    describe ".resolved_element_order" do
      context "when given element contains element_order but no instance relevant elements/instances" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.element_order = ["annotation", "simple_type", "complex_type", "key"]
          end
        end

        it "raises an error when element_order contains elements that isn't an attribute of the instance" do
          element.element_order << "test_element"
          expect { described_class.send(:resolved_element_order, element) }.to raise_error(NoMethodError)
        end

        it "returns the array with nil values" do
          expected_hash = [nil, nil, nil, nil]
          expect(described_class.send(:resolved_element_order, element)).to eql(expected_hash)
        end
      end

      context "when given element contains element_order but with relevant elements/instances" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.annotation = Lutaml::Xsd::Annotation.new
            element.simple_type = Lutaml::Xsd::SimpleType.new
            element.complex_type = Lutaml::Xsd::ComplexType.new
            element.key = Lutaml::Xsd::Key.new
            element.element_order = ["annotation", "simple_type", "complex_type", "key"]
          end
        end

        let(:expected_hash) { [element.annotation, element.simple_type, element.complex_type, element.key] }

        it "returns the expected hash" do
          expect(described_class.send(:resolved_element_order, element)).to eql(expected_hash)
        end
      end

      context "when given element contains empty element_order with elements/instances" do
        let(:element) do
          Lutaml::Xsd::Element.new.tap do |element|
            element.element_order = []
          end
        end

        it "returns the expected hash" do
          expect(described_class.send(:resolved_element_order, element)).to be_empty
        end
      end
    end
  end

  describe "structure to template content resolving methods" do
    describe ".resolve_parent_class" do
      context "when complex_content.extension is not present" do
        it "returns Lutaml::Model::Serializable" do
          expect(described_class.send(:resolve_parent_class, {})).to eql("Lutaml::Model::Serializable")
        end
      end

      context "when complex_content.extension is present" do
        it "returns the extension_base value" do
          content = { complex_content: { extension: { extension_base: "ST_Parent" } } }
          expect(described_class.send(:resolve_parent_class, content)).to eql("STParent")
        end
      end
    end

    describe ".resolve_attribute_class" do
      context "when attribute.base_class is one of the standard classes" do
        described_class::DEFAULT_CLASSES.each do |standard_class|
          it "returns the attribute_class value for #{standard_class.capitalize}" do
            base_class_hash = to_mapping_hash({ base_class: "xsd:#{standard_class}" })
            expect(described_class.send(:resolve_attribute_class, base_class_hash)).to eql(":#{standard_class}")
          end
        end
      end

      context "when attribute.base_class is not one of the standard classes" do
        it "returns the attribute_class value" do
          base_class_hash = to_mapping_hash({ base_class: "test_st_attr1" })
          expect(described_class.send(:resolve_attribute_class, base_class_hash)).to eql("TestStAttr1")
        end
      end
    end

    describe ".resolve_occurs" do
      context "when min_occurs and max_occurs are present" do
        it "returns the collection: true" do
          base_class_hash = to_mapping_hash({ min_occurs: 0, max_occurs: "unbounded" })
          expect(described_class.send(:resolve_occurs, base_class_hash)).to eql(", collection: true")
        end

        it "returns the collection: 0..1" do
          base_class_hash = to_mapping_hash({ min_occurs: 0, max_occurs: 1 })
          expect(described_class.send(:resolve_occurs, base_class_hash)).to eql(", collection: 0..1")
        end
      end

      context "when min_occurs/max_occurs are not present" do
        it "returns the collection: 0.." do
          base_class_hash = to_mapping_hash({ min_occurs: 0, max_occurs: 1 })
          expect(described_class.send(:resolve_occurs, base_class_hash)).to eql(", collection: 0..1")
        end
      end
    end

    describe ".resolve_elements" do
      before do
        described_class.instance_variable_set(:@elements, elements)
      end

      after do
        described_class.instance_variable_set(:@elements, nil)
      end

      let(:elements) do
        to_mapping_hash({ "testRef" => to_mapping_hash({ element_name: "testElement" }) })
      end

      context "when elements contain ref_class and base_class elements" do
        it "returns the elements hash" do
          content = [to_mapping_hash({ ref_class: "testRef" }), to_mapping_hash({ element_name: "testElement1" })]
          expected_elements = { "testElement" => { element_name: "testElement" }, "testElement1" => { element_name: "testElement1" } }
          expect(described_class.send(:resolve_elements, content)).to eql(expected_elements)
        end
      end
    end

    describe ".resolve_content" do
      let(:content) do
        {
          sequence: [],
          choice: [],
          group: [],
        }
      end

      context "when content contain empty sequence, choice and group" do
        it "returns the elements hash" do
          expect(described_class.send(:resolve_content, content)).to be_empty
        end
      end
    end

    describe ".resolve_sequence" do
      let(:sequence) do
        {
          sequence: [],
          elements: [],
          groups: [],
          choice: [],
        }
      end

      context "when sequence contain empty elements and other empty attributes" do
        it "returns the elements empty hash" do
          expect(described_class.send(:resolve_sequence, sequence)).to be_empty
        end
      end
    end

    describe ".resolve_choice" do
      let(:choice) do
        {
          "string" => to_mapping_hash({ element_name: "testElement" }),
          sequence: [],
          element: [],
          group: [],
        }
      end

      context "when choice contain empty elements and other empty attributes" do
        it "returns the one element hash" do
          expect(described_class.send(:resolve_choice, choice)).to eql({ "string" => { element_name: "testElement" } })
        end
      end
    end

    describe ".resolve_group" do
      before do
        described_class.instance_variable_set(:@group_types, group_types)
      end

      after do
        described_class.instance_variable_set(:@group_types, nil)
      end

      let(:group_types) { { "testRef" => {} } }

      let(:group) do
        {
          ref_class: "testRef",
          sequence: [],
          choice: [],
          group: [],
        }
      end

      context "when group contain ref_class and other empty attributes" do
        it "returns the one element hash" do
          expect(described_class.send(:resolve_group, group)).to be_empty
        end
      end
    end

    describe ".resolve_complex_content" do
      let(:complex_content) do
        {
          extension: {},
          restriction: {},
        }
      end

      context "when complex_content contain extension and restriction" do
        it "returns the one element hash" do
          expect(described_class.send(:resolve_complex_content, complex_content)).to be_empty
        end
      end
    end

    describe ".resolve_extension" do
      let(:extension) do
        {
          attributes: [{ base_class: "ST_Attr1", default: "1" }, { base_class: "ST_Attr2", default: "2" }],
          sequence: {},
          choice: {},
        }
      end

      context "when extension contain attributes, sequence and choice" do
        it "returns the one element hash" do
          expect(described_class.send(:resolve_extension, to_mapping_hash(extension))).to eql({ attributes: extension[:attributes] })
        end
      end
    end

    describe ".resolve_attribute_default" do
      context "when attribute contain default" do
        it "returns the string with default value" do
          attribute = to_mapping_hash({ base_class: "ST_Attr1", default: "1" })
          expect(described_class.send(:resolve_attribute_default, attribute)).to eql(", default: \"1\"")
        end
      end

      context "when attribute contain no default" do
        it "returns the string with nil as default value" do
          attribute = to_mapping_hash({ base_class: "ST_Attr1" })
          expect(described_class.send(:resolve_attribute_default, attribute)).to eql(", default: nil")
        end
      end
    end

    describe ".resolve_attribute_default_value" do
      context "when attribute data type is one of the standard classes" do
        let(:standard_class_value) do
          {
            "int" => { input: "1", output: 1 },
            "integer" => { input: "12", output: 12 },
            "string" => { input: "test_string", output: "test_string" },
            "boolean" => { input: "false", output: false },
          }
        end

        described_class::DEFAULT_CLASSES.each do |standard_class|
          it "returns the value as the #{standard_class.capitalize} class instance" do
            default_value = standard_class_value[standard_class]
            expect(described_class.send(:resolve_attribute_default_value, standard_class, default_value[:input])).to eql(default_value[:output])
          end
        end
      end

      context "when attribute data type is not one of the standard classes" do
        it "returns the string with default value" do
          expect(described_class.send(:resolve_attribute_default_value, "BooleanTestClass", "1")).to eql("\"1\"")
        end
      end
    end

    describe ".resolve_namespace" do
      context "when namespace is given" do
        it "returns the string with namespace" do
          expect(described_class.send(:resolve_namespace, { namespace: "testNamespace" })).to eql("namespace \"testNamespace\"\n")
        end
      end

      context "when namespace and prefix are given" do
        it "returns the string with namespace and prefix" do
          expect(described_class.send(:resolve_namespace, { namespace: "testNamespace", prefix: "testPrefix" })).to eql("namespace \"testNamespace\", \"testPrefix\"\n")
        end
      end

      context "when namespace and prefix are not given" do
        it "returns the string with nil" do
          expect(described_class.send(:resolve_namespace, {})).to be_nil
        end
      end
    end
  end

  describe "required files list compiler methods" do
    describe ".resolve_required_files" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
        end

        let(:content) do
          {
            attribute_groups: {},
            complex_content: {},
            simple_content: {},
            attributes: {},
            sequence: {},
            choice: {},
            group: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:resolve_required_files, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql([])
        end
      end
    end

    describe ".required_files_simple_content" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
        end

        let(:content) do
          {
            extension_base: {},
            attributes: {},
            extension: {},
            restriction: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_simple_content, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql([])
        end
      end
    end

    describe ".required_files_complex_content" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
        end

        let(:content) do
          {
            extension: {},
            restriction: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_complex_content, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql([])
        end
      end
    end

    describe ".required_files_extension" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
        end

        let(:content) do
          {
            attribute_group: {},
            extension_base: {},
            attributes: {},
            attribute: {},
            sequence: {},
            choice: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_extension, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql([])
        end
      end
    end

    describe ".required_files_restriction" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
        end

        let(:content) { { base: "testId" } }

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_restriction, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql(["test_id"])
        end
      end
    end

    describe ".required_files_attribute_groups" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
          described_class.instance_variable_set(:@attribute_groups, attribute_groups)
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
          described_class.instance_variable_set(:@attribute_groups, nil)
        end

        let(:attribute_groups) { { "testId" => {} } }

        let(:content) do
          {
            ref_class: "testId",
            attributes: {},
            attribute: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_attribute_groups, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql([])
        end
      end
    end

    describe ".required_files_attribute" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
          described_class.instance_variable_set(:@attributes, attributes)
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
          described_class.instance_variable_set(:@attributes, nil)
        end

        let(:attributes) do
          {
            "testRef" => to_mapping_hash({ base_class: "ST_Attr1" }),
          }
        end

        let(:content) do
          [
            to_mapping_hash({ ref_class: "testRef" }),
            to_mapping_hash({ base_class: "ST_Attr2" }),
          ]
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_attribute, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql(["st_attr1", "st_attr2"])
        end
      end
    end

    describe ".required_files_choice" do
      context "when elements are given" do
        before { described_class.instance_variable_set(:@required_files, []) }
        after { described_class.instance_variable_set(:@required_files, nil) }

        let(:content) do
          {
            "testRef" => to_mapping_hash({ type_name: "ST_Attr1" }),
            sequence: {},
            element: {},
            choice: {},
            group: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_choice, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql(["st_attr1"])
        end
      end
    end

    describe ".required_files_group" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
          described_class.instance_variable_set(:@group_types, group_types)
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
          described_class.instance_variable_set(:@group_types, nil)
        end

        let(:group_types) { { "testRef" => {} } }
        let(:content) do
          {
            ref_class: "testRef",
            sequence: {},
            choice: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_group, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql([])
        end
      end
    end

    describe ".required_files_sequence" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
        end

        let(:content) do
          {
            elements: {},
            sequence: {},
            groups: {},
            choice: {},
          }
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_sequence, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql([])
        end
      end
    end

    describe ".required_files_elements" do
      context "when elements are given" do
        before do
          described_class.instance_variable_set(:@required_files, [])
          described_class.instance_variable_set(:@elements, elements)
        end

        after do
          described_class.instance_variable_set(:@required_files, nil)
          described_class.instance_variable_set(:@elements, nil)
        end

        let(:elements) do
          {
            "CT_Element1" => to_mapping_hash({ type_name: "w:CT_Element1" }),
          }
        end

        let(:content) do
          [
            to_mapping_hash({ ref_class: "CT_Element1" }),
            to_mapping_hash({ type_name: "CT_Element2" }),
          ]
        end

        it "populates @required_files variable with the names of the required files" do
          described_class.send(:required_files_elements, content)
          expect(described_class.instance_variable_get(:@required_files)).to eql(["ct_element1", "ct_element2"])
        end
      end
    end
  end
end

def to_mapping_hash(content)
  @hash ||= Lutaml::Model::MappingHash.new
  @hash.merge(content)
end
