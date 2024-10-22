require "spec_helper"
require "lutaml/model"

module InheritanceSpec
  class Parent < Lutaml::Model::Serializable
    attribute :text, Lutaml::Model::Type::String
    attribute :id, Lutaml::Model::Type::String
    attribute :name, Lutaml::Model::Type::String

    xml do
      map_content to: :text

      map_attribute "id", to: :id
      map_element "name", to: :name
    end
  end

  class Child < Parent
    attribute :age, Lutaml::Model::Type::Integer

    xml do
      root "child"

      map_element "age", to: :age
    end
  end

  class Child2 < Parent
    attribute :age, Lutaml::Model::Type::Integer

    xml do
      root "child_two"

      map_element "gender", to: :age
    end
  end
end

RSpec.describe "Inheritance" do
  subject(:child_object) do
    InheritanceSpec::Child.new(
      {
        text: "Some text",
        name: "John Doe",
        id: "foobar",
        age: 30,
      },
    )
  end

  let(:expected_xml) do
    '<child id="foobar"><name>John Doe</name><age>30</age>Some text</child>'
  end

  it "uses parent attributes" do
    expect(child_object.to_xml(pretty: true)).to eq(expected_xml)
  end

  context "with multiple child classes" do
    it "has correct mappings" do
      expect(InheritanceSpec::Child.mappings_for(:xml).mappings.count).to eq(4)
      expect(InheritanceSpec::Child2.mappings_for(:xml).mappings.count).to eq(4)
    end

    it "has correct attributes" do
      expect(InheritanceSpec::Child.attributes.count).to eq(4)
      expect(InheritanceSpec::Child2.attributes.count).to eq(4)
    end
  end
end
