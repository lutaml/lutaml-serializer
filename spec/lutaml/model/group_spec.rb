require "spec_helper"
require "lutaml/model"

module GroupSpec
  class Ceramic < Lutaml::Model::Serializable
    attribute :type, :string
    attribute :name, :string

    xml do
      no_root
      map_element :type, to: :type
      map_element :name, to: :name
    end
  end

  class CeramicCollection < Lutaml::Model::Serializable
    attribute :ceramic, Ceramic, collection: 1..2

    xml do
      root "collection"
      map_element "ceramic", to: :ceramic
    end
  end

  class AttributeValueType < Lutaml::Model::Type::Decimal
  end

  class GroupOfItems < Lutaml::Model::Serializable
    attribute :name, :string
    attribute :type, :string
    attribute :description, :string
    attribute :code, :string

    xml do
      no_root
      sequence do
        map_element "name", to: :name
        map_element "type", to: :type
        map_element "description", to: :description
      end
      map_attribute "code", to: :code
    end
  end

  class ComplexType < Lutaml::Model::Serializable
    attribute :tag, AttributeValueType
    attribute :content, :string
    attribute :group, :string
    import_model_attributes GroupOfItems

    xml do
      root "GroupOfItems"
      map_attribute "tag", to: :tag
      map_content to: :content
      map_element :group, to: :group
      import_model_mappings GroupOfItems
    end
  end

  class SimpleType < Lutaml::Model::Serializable
    import_model GroupOfItems
  end

  class GenericType < Lutaml::Model::Serializable
    import_model_mappings GroupOfItems
  end
end

RSpec.describe "Group" do
  context "with no_root" do
    let(:mapper) { GroupSpec::CeramicCollection }

    it "raises error if root-less class used directly for parsing" do
      xml = <<~XML
        <type>Data</type>
        <name>Smith</name>
      XML

      expect { GroupSpec::Ceramic.from_xml(xml) }.to raise_error(
        Lutaml::Model::NoRootMappingError,
        "`no_root` is only allowed for Group classes",
      )
    end

    it "raises error if root_less class used for deserializing" do
      ceramic = GroupSpec::Ceramic.new(type: "Data", name: "Starc")

      expect { ceramic.to_xml }.to raise_error(
        Lutaml::Model::NoRootMappingError,
        "`no_root` is only allowed for Group classes",
      )
    end

    it "correctly get the element of root-less class" do
      xml = <<~XML
        <collection>
          <ceramic>
            <type>Data</type>
          </ceramic>
        </collection>
      XML

      expect { mapper.from_xml(xml) }.not_to raise_error
    end
  end

  context "with model" do
    it "import attributes" do
      expect(GroupSpec::ComplexType.attributes).to include(GroupSpec::GroupOfItems.attributes)
    end

    it "import mappings in xml block" do
      expect(GroupSpec::ComplexType.mappings_for(:xml).elements).to include(*GroupSpec::GroupOfItems.mappings_for(:xml).elements)
    end

    it "import mappings outside xml block" do
      expect(GroupSpec::GenericType.mappings_for(:xml).elements).to include(*GroupSpec::GroupOfItems.mappings_for(:xml).elements)
    end

    it "import attributes and mappings in xml block" do
      expect(GroupSpec::ComplexType.attributes).to include(GroupSpec::GroupOfItems.attributes)
      expect(GroupSpec::ComplexType.mappings_for(:xml).elements).to include(*GroupSpec::GroupOfItems.mappings_for(:xml).elements)
    end

    it "import attributes and mappings outside the xml block" do
      expect(GroupSpec::SimpleType.attributes).to include(GroupSpec::GroupOfItems.attributes)
      expect(GroupSpec::SimpleType.mappings_for(:xml).elements).to include(*GroupSpec::GroupOfItems.mappings_for(:xml).elements)
    end
  end
end
