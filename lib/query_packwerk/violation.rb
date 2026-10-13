# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # Represents a single Packwerk violation with extended inspection capabilities.
  # Provides methods to analyze violation details including source location, contextual
  # information, and code patterns. Facilitates both detailed and anonymized views of
  # dependency violations between packages.
  class Violation < ConstantUse
    extend T::Sig

    sig { override.returns(QueryPackwerk::Package) }
    attr_reader :producing_pack

    sig { override.returns(QueryPackwerk::Package) }
    attr_reader :consuming_pack

    sig do
      params(
        original_violation: ParsePackwerk::Violation,
        consuming_pack: ParsePackwerk::Package,
        file_cache: QueryPackwerk::FileCache
      ).void
    end
    def initialize(original_violation:, consuming_pack:, file_cache: QueryPackwerk::FileCache.new)
      super(file_cache:)
      @original_violation = original_violation

      @producing_pack = T.let(
        QueryPackwerk::Package.new(original_package: T.must(ParsePackwerk.find(original_violation.to_package_name))),
        QueryPackwerk::Package
      )

      @consuming_pack = T.let(
        QueryPackwerk::Package.new(original_package: consuming_pack),
        QueryPackwerk::Package
      )
    end

    # Forwarding original properties explicitly.

    sig { returns(String) }
    def type
      @original_violation.type
    end

    sig { returns(String) }
    def to_package_name
      @original_violation.to_package_name
    end

    sig { override.returns(String) }
    def class_name
      @original_violation.class_name
    end

    sig { override.returns(T::Array[String]) }
    def files
      @original_violation.files
    end

    # package_todo.yml records a violation's files but not where in them it is,
    # so its sources are wherever a file names the constant
    sig { override.params(file_name: String).returns(T::Array[RuboCop::AST::Node]) }
    def full_sources_in(file_name)
      @file_cache.get_full_sources(file_name: file_name, class_name: class_name)
    end

    sig do
      params(keys: T.nilable(T::Array[Symbol])).returns(T::Hash[Symbol, T.untyped])
    end
    def deconstruct_keys(keys)
      all_values = {
        constant_name: class_name,
        pack_name: to_package_name,

        # Type related properties, including convenience boolean handlers
        type: type,
        privacy: type == 'privacy',
        dependency: type == 'dependency',

        # Reaching into which pack produced the violated constant, and
        # which consumes the violated constant.
        consuming_pack: consuming_pack.name,
        producing_pack: producing_pack.name,

        # Same, except for owners
        producing_owner: producing_pack.owner,
        consuming_owner: consuming_pack.owner,

        # So why is this "owner" implying producer? Because the
        # owner field of the violation is producer-oriented.
        owner: producing_pack.owner,
        owned: producing_pack.owner.nil?,

        **runtime_keys(keys)
      }

      keys.nil? ? all_values : all_values.slice(*T.unsafe(keys))
    end

    sig { returns(String) }
    def inspect
      "#<#{self.class.name} #{consuming_pack.name} -> #{class_name} (#{type})>"
    end
  end
end
