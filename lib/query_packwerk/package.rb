# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # Represents a Packwerk package with enhanced querying capabilities.
  # Wraps around ParsePackwerk::Package to provide additional methods
  # for accessing package properties, dependencies, violations, and consumer information.
  class Package
    extend T::Sig

    sig { returns(ParsePackwerk::Package) }
    attr_reader :original_package

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

    sig { returns(T::Hash[String, T.untyped]) }
    def config
      @original_package.config
    end

    sig { returns(QueryPackwerk::Packages) }
    def dependencies
      Packages.where(name: @original_package.dependencies)
    end

    sig { returns(T::Array[String]) }
    def dependency_names
      @original_package.dependencies
    end

    sig { returns(String) }
    def owner
      config['owner'] || Packages::UNOWNED
    end

    sig { returns(Pathname) }
    def directory
      Pathname.new(name).cleanpath
    end

    # Returns violations where this package is the consumer (i.e., this package
    # has dependencies on other packages). These are the "todos" in the package_todo.yml
    # file for this package.
    sig { returns(QueryPackwerk::Violations) }
    def todos
      QueryPackwerk::Violations.where(consuming_pack: name)
    end
    alias outgoing_violations todos

    # Returns violations where this package is the producer (i.e., other packages
    # depend on this package). These are violations where other packages are
    # accessing code from this package.
    sig { returns(QueryPackwerk::Violations) }
    def violations
      QueryPackwerk::Violations.where(producing_pack: name)
    end
    alias incoming_violations violations

    # Returns all packages that consume (depend on) this package
    sig { returns(QueryPackwerk::Packages) }
    def consumers
      Packages.where(name: consumer_names)
    end

    # Returns the names of all packages that consume (depend on) this package
    sig { returns(T::Array[String]) }
    def consumer_names
      violations.consumers.keys
    end

    # Returns a count of how often each consumer package accesses this package
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
        owner: owner,
        owned: owner != Packages::UNOWNED,
        dependencies: dependency_names,

        # Used for future implementations of NestedPacks
        parent_name: parent_name
      }

      keys.nil? ? all_values : all_values.slice(*T.unsafe(keys))
    end

    sig { returns(String) }
    def inspect
      "#<#{self.class.name} #{name}>"
    end
  end
end
