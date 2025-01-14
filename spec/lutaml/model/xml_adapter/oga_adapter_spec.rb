require "spec_helper"
require "oga"
require_relative "../../../../lib/lutaml/model/xml_adapter/oga_adapter"

RSpec.describe Lutaml::Model::XmlAdapter::OgaAdapter do
  before do
    Lutaml::Model::Config.xml_adapter_type = :oga
  end

  let(:xml_string) do
    <<~XML
      <root xmlns="http://example.com/default" xmlns:prefix="http://example.com/prefixed">
        <prefix:child attr="value" prefix:attr="prefixed_value">Text</prefix:child>
      </root>
    XML
  end

  let(:document) { described_class.parse(xml_string) }

  context "parsing XML with namespaces" do
    let(:child) { document.root.children.first }

    it "parses the root element with default namespace" do
      expect(document.root.name).to eq("root")
      expect(document.root.native.namespace.uri).to eq("http://example.com/default")
      expect(document.root.native.namespace.name).to eq("xmlns")
    end

    it "parses child element with prefixed namespace" do
      expect(child.native.expanded_name).to eq("prefix:child")
      expect(child.namespace.uri).to eq("http://example.com/prefixed")
      expect(child.namespace.prefix).to eq("prefix")
    end

    it "parses attributes with and without namespaces" do
      prefixed_attr = child.attributes.find { |attr| attr.native.expanded_name == "prefix:attr" }
      no_prefixed_attr = child.attributes.find { |attr| attr.native.expanded_name == "attr" }
      expect(no_prefixed_attr.value).to eq("value")
      expect(no_prefixed_attr.namespace).to be_nil
      expect(prefixed_attr.value).to eq("prefixed_value")
      expect(prefixed_attr.namespace.uri).to eq("http://example.com/prefixed")
      expect(prefixed_attr.namespace.prefix).to eq("prefix")
    end
  end

  context "generating XML with namespaces" do
    it "generates XML with namespaces correctly" do
      xml_output = document.root.to_xml
      parsed_output = Moxml::Adapter::Oga.parse(xml_output)

      root = parsed_output.children.first
      expect(root.name).to eq("root")
      expect(root.namespace.uri).to eq("http://example.com/default")

      child = root.children.first
      expect(child.native.expanded_name).to eq("prefix:child")
      expect(child.namespace.uri).to eq("http://example.com/prefixed")
      unprefixed_attr = child.attributes.find { |attr| attr.name == "attr" }
      expect(unprefixed_attr.value).to eq("value")
      prefixed_attr = child.attributes.find { |attr| attr.native.expanded_name == "prefix:attr" }
      expect(prefixed_attr.value).to eq("prefixed_value")
    end
  end
end
