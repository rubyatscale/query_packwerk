# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::QueryInterface do
  let(:person) do
    Struct.new(:name, :age, :sex, :hobbies, keyword_init: true) do
      def deconstruct_keys(keys)
        all_values = {
          name: name,
          age: age,
          adult: age >= 18,
          sex: sex,
          hobbies: hobbies,
          male: sex == "male",
          female: sex == "female",
          nonbinary: sex != "female" && sex != "male"
        }

        keys.nil? ? all_values : all_values.slice(*keys)
      end
    end
  end

  let(:all_people) do
    [
      person.new(name: "Bob", age: 42, sex: "male", hobbies: %w[trains planes]),
      person.new(name: "Sue", age: 24, sex: "female", hobbies: %w[painting singing]),
      person.new(name: "Ryan", age: 30, sex: "unspecified", hobbies: %w[fencing gardening]),
      person.new(name: "Kai", age: 17, sex: "male", hobbies: %w[piano climbing])
    ]
  end

  let(:people) do
    current_all_people = all_people

    # Why all the `define_method`s? Sorbet does not play well with anonymous
    # classes and we'd like to not pollute the global namespace, so this was
    # the compromise.
    #
    # See: https://github.com/sorbet/sorbet/issues/3609
    Class.new do
      # Bring into scope
      define_singleton_method(:get_all_people) { current_all_people }

      include QueryPackwerk::QueryInterface

      attr_reader :original_collection

      define_method(:initialize) do |people|
        @original_collection = people
      end

      class << self
        define_method(:all) do
          new(get_all_people)
        end

        define_method(:where) do |**query_params, &query_fn|
          new(super(**query_params, &query_fn))
        end

        define_method(:param_mapping) do
          {
            name: lambda(&:name),
            age: lambda(&:age),
            adult: ->(v) { v.age >= 18 },
            sex: lambda(&:sex),
            hobbies: lambda(&:hobbies),
            male: ->(v) { v.sex == "male" },
            female: ->(v) { v.sex == "female" },
            nonbinary: ->(v) { v.sex != "female" && v.sex != "male" }
          }
        end
      end
    end
  end

  describe ".all" do
    it "returns all people" do
      expect(people.all).to be_a(people)
    end
  end

  describe ".where" do
    it "can get people by conditions" do
      expect(people.where(adult: true).count).to eq(3)
    end

    it "can work with === interfaces" do
      expect(people.where(age: 20..30).count).to eq(2)
    end

    it "can work with array inclusion" do
      expect(people.where(name: %w[Sue Bob]).count).to eq(2)
    end

    it "can work with multiple conditions" do
      expect(people.where(adult: true, nonbinary: true).count).to eq(1)
    end

    it "can search into nested Arrays" do
      expect(people.where(hobbies: "piano").count).to eq(1)
    end

    it "can check for multiple potential Array matches" do
      expect(people.where(hobbies: %w[piano fencing]).count).to eq(2)
    end
  end

  describe "#count" do
    it "can get the count/size/length of a query" do
      expect(people.all.count).to eq(4)
    end
  end

  describe "#each" do
    it "includes an Enumerable interface" do
      # It's making assumptions about `all` in the context of RSpec which don't make sense.
      people.all.each do |a_person|
        expect(a_person).to be_a(person)
      end
    end
  end
end
