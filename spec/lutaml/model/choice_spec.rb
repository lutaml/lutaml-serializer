require "spec_helper"
require "lutaml/model"

module ChoiceSpec
  class CandidateType < Lutaml::Model::Serializable
    attribute :id, :integer
    attribute :name, :string

    xml do
      map_attribute "id", to: :id
      map_attribute "name", to: :name
    end
  end

  class ChadState < Lutaml::Model::Serializable
    choice(min: 1, max: 3) do
      attribute :selected, :boolean
      attribute :unselected, :boolean
      attribute :dimpled, :boolean
      attribute :perforated, :boolean
    end

    attribute :candidate, CandidateType

    xml do
      map_element "selected", to: :selected
      map_element "unselected", to: :unselected
      map_element "dimpled", to: :dimpled
      map_element "perforated", to: :perforated
      map_attribute "candidate", to: :candidate
    end
  end

  class PersonDetails < Lutaml::Model::Serializable
    choice(min: 1, max: 2) do
      attribute :first_name, :string
      choice(min: 2, max: 2) do
        attribute :email, :string
        attribute :phone, :string
      end
    end

    key_value do
      map :first_name, to: :first_name
      map :email, to: :email
      map :phone, to: :phone
      map :fb, to: :fb
      map :insta, to: :insta
    end
  end
end

RSpec.describe "Choice" do
  context "with choice option" do
    let(:mapper) { ChoiceSpec::ChadState }

    it "returns an empty array for a valid choice instance" do
      valid_instance = mapper.new(
        selected: true,
        unselected: true,
        dimpled: false,
        candidate: ChoiceSpec::CandidateType.new(id: 1, name: "Smith"),
      )

      expect(valid_instance.validate).to be_empty
    end

    it "returns nil for a valid instance, if given attributes for choice are within defined range" do
      valid_instance = mapper.new(
        dimpled: false,
        perforated: true,
      )

      expect(valid_instance.validate!).to be_nil
    end

    it "raises error, if attributes given for choice are out of range" do
      valid_instance = mapper.new(
        selected: true,
        unselected: false,
        dimpled: false,
        perforated: true,
      )

      expect { valid_instance.validate! }.to raise_error(Lutaml::Model::ValidationError) do |error|
        expect(error.error_messages.join("\n")).to include("Attributes must be in specified range in a choice")
      end
    end
  end

  context "with nested choice option" do
    let(:mapper) { ChoiceSpec::PersonDetails }

    it "returns an empty array for a valid instance" do
      valid_instance = mapper.new(
        first_name: "John",
      )

      expect(valid_instance.validate).to be_empty
    end

    it "returns nil for a valid instance" do
      valid_instance = mapper.new(
        email: "email",
        phone: "02344",
      )

      expect(valid_instance.validate!).to be_nil
    end

    it "raises error, if given attribute for choice are not within defined range" do
      valid_instance = mapper.new(
        first_name: "Nick",
        email: "email",
        phone: "phone",
      )

      expect { valid_instance.validate! }.to raise_error(Lutaml::Model::ValidationError) do |error|
        expect(error.error_messages.join("\n")).to include("Attributes must be in specified range in a choice")
      end
    end

    it "raises error, if min, max is not positive" do
      expect do
        Class.new(Lutaml::Model::Serializable) do
          choice(min: -1, max: -2) do
            attribute :id, :integer
            attribute :name, :string
          end
        end
      end.to raise_error(StandardError, "Choice range must be positive")
    end
  end
end
