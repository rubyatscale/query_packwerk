# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # Represents a Packwerk package with enhanced querying capabilities.
  # Wraps around ParsePackwerk::Package to provide additional methods
  # for accessing package properties, dependencies, violations, and consumer information.
  class Package
    extend T::Sig

    sig { params(original_package: ParsePackwerk::Package).void }
    def initialize(original_package:)
      @original_package = original_package
    end

    sig { returns(String) }
    def name
      @original_package.name
    end

    sig { returns(T::Boolean) }
    def enforce_dependencies
      !!@original_package.enforce_dependencies
    end

    sig { returns(T::Boolean) }
    def enforce_privacy
      !!@original_package.enforce_privacy
    end

    sig { returns(ParsePackwerk::MetadataYmlType) }
    def metadata
      @original_package.metadata
    end

    sig { returns(T::Array[String]) }
    def dependencies
      @original_package.dependencies
    end

    sig { returns(String) }
    def owner
      metadata["owner"] || Packages::UNOWNED
    end

    sig { returns(Pathname) }
    def directory
      Pathname.new(name).cleanpath
    end

    sig { returns(QueryPackwerk::Violations) }
    def violations
      QueryPackwerk::Violations.where(producing_pack: name)
    end

    sig { returns(T::Array[String]) }
    def consumers
      violations.consumers.keys
    end

    sig { returns(T::Hash[String, Integer]) }
    def consumer_counts
      violations.consumers
    end

    sig { returns(String) }
    def parent_name
      directory.dirname.to_s
    end

    sig do
      params(
        keys: T.nilable(T::Array[Symbol])
      ).returns(T::Hash[Symbol, T.untyped])
    end
    def deconstruct_keys(keys)
      all_values = {
        name: name,
        owner: metadata.fetch("owner", Packages::UNOWNED),
        owned: metadata["owner"].nil?,
        dependencies: dependencies,

        # Used for future implementations of NestedPacks
        parent_name: parent_name
      }

      keys.nil? ? all_values : all_values.slice(*T.unsafe(keys))
    end
  end
end
