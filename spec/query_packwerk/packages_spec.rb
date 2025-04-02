# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::Packages do
  include_context 'pseudo packs'

  describe '#where' do
    it 'can query packages' do
      packages = described_class.where(owner: QueryPackwerk::Packages::UNOWNED)
      expect(packages).to be_a(described_class)
      expect(packages.map(&:owner).uniq).to eq([QueryPackwerk::Packages::UNOWNED])
    end
  end

  describe '#empty? and #any?' do
    it 'returns true for empty? when there are no packages' do
      empty_packages = described_class.new([])
      expect(empty_packages.empty?).to be true
      expect(empty_packages.any?).to be false
    end

    it 'returns false for empty? when there are packages' do
      expect(described_class.all.empty?).to be false
      expect(described_class.all.any?).to be true
    end

    it 'supports any? with a block' do
      packages = described_class.all
      expect(packages.any? { |p| p.owner == QueryPackwerk::Packages::UNOWNED }).to be true
      expect(packages.any? { |p| p.name == 'nonexistent' }).to be false
    end
  end

  describe '#violations' do
    it 'returns violations for all packages in the collection' do
      packages = described_class.all
      violations = packages.violations
      expect(violations).to be_a(QueryPackwerk::Violations)
      expect(violations.count).to be > 0
    end
  end

  describe '#inspect' do
    it 'returns a string representation of an empty collection' do
      packages = described_class.new([])
      expect(packages.inspect).to eq("#<#{described_class.name} []>")
    end

    it 'returns a string representation of the packages' do
      packages = described_class.all
      expect(packages.inspect).to eq("#<#{described_class.name} [\n#{described_class.all.map(&:inspect).join("\n")}\n]>")
    end
  end
end
