# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::Package do
  include_context 'pseudo packs'

  let(:package) { QueryPackwerk.package(package_name) }

  describe '#name' do
    it 'returns the package name' do
      expect(package.name).to eq(package_name)
    end
  end

  describe '#enforce_dependencies' do
    it 'returns whether dependencies are enforced' do
      expect(package.enforce_dependencies).to be true
    end
  end

  describe '#enforce_privacy' do
    it 'returns whether privacy is enforced' do
      expect(package.enforce_privacy).to be true
    end
  end

  describe '#metadata' do
    it 'returns the package metadata' do
      expect(package.metadata).to be_a(Hash)
    end
  end

  describe '#dependencies' do
    it 'returns the package dependencies as a Packages collection' do
      expect(package.dependencies).to be_a(QueryPackwerk::Packages)
    end
  end

  describe '#dependency_names' do
    it 'returns an array of dependency names' do
      expect(package.dependency_names).to be_an(Array)
    end
  end

  describe '#owner' do
    it 'returns the owner or unowned constant' do
      expect(package.owner).to eq(QueryPackwerk::Packages::UNOWNED)
    end
  end

  describe '#directory' do
    it 'returns a Pathname representing the package directory' do
      expect(package.directory).to be_a(Pathname)
      expect(package.directory.to_s).to eq(package_name)
    end
  end

  describe '#todos' do
    it 'returns violations for the package' do
      todos = package.todos
      expect(todos).to be_a(QueryPackwerk::Violations)
      expect(todos.size).to eq(raw_violations.size)
    end
  end

  describe '#dependency_violations' do
    it 'is an alias for #todos' do
      # Both methods should return equivalent objects but might not be equal with `==`
      expect(package.todos.to_a).to match_array(package.dependency_violations.to_a)
    end
  end

  describe '#violations' do
    it 'returns violations where this package is the producing pack' do
      violations = package.violations
      expect(violations).to be_a(QueryPackwerk::Violations)
    end
  end

  describe '#consumer_violations' do
    it 'is an alias for #violations' do
      # Both methods should return equivalent objects but might not be equal with `==`
      expect(package.consumer_violations.to_a).to match_array(package.violations.to_a)
    end
  end

  describe '#consumers' do
    it 'returns packages that have violations against this package' do
      expect(package.consumers).to be_a(QueryPackwerk::Packages)
    end
  end

  describe '#consumer_names' do
    it 'returns an array of consumer package names' do
      expect(package.consumer_names).to be_an(Array)
    end
  end

  describe '#consumer_counts' do
    it 'returns a hash of consumer package names to violation counts' do
      expect(package.consumer_counts).to be_a(Hash)
    end
  end

  describe '#parent_name' do
    it 'returns the parent directory name' do
      expect(package.parent_name).to eq('packs')
    end
  end

  describe '#deconstruct_keys' do
    it 'returns a hash of values for pattern matching' do
      result = package.deconstruct_keys(%i[name owner dependencies])
      expect(result).to be_a(Hash)
      expect(result.keys).to include(:name, :owner, :dependencies)
      expect(result[:name]).to eq(package_name)
    end

    it 'returns all values when keys is nil' do
      result = package.deconstruct_keys(nil)
      expect(result).to be_a(Hash)
      expect(result.keys).to include(:name, :owner, :dependencies, :owned, :parent_name)
    end
  end

  describe '#inspect' do
    it 'returns a string representation of the package' do
      expect(package.inspect).to eq("#<QueryPackwerk::Package #{package_name}>")
    end
  end
end
