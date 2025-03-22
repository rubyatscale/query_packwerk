# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # A collection class for managing and querying sets of Packwerk packages.
  # Provides methods for retrieving, filtering, and analyzing packages within
  # the application. Implements Enumerable and QueryInterface for flexible
  # data manipulation and consistent query patterns.
  class Packages
    extend T::Sig
    extend T::Generic

    Elem = type_member { { fixed: QueryPackwerk::Package } }

    UNOWNED = T.let('Unowned', String)

    include Enumerable
    include QueryInterface

    sig { override.returns(T::Array[QueryPackwerk::Package]) }
    attr_reader :original_collection

    class << self
      extend T::Sig

      # Get all packages wrapped in our interfaces
      sig { returns(QueryPackwerk::Packages) }
      def all
        @all ||= T.let(
          begin
            packages = ParsePackwerk.all.map { |p| QueryPackwerk::Package.new(original_package: p) }
            QueryPackwerk::Packages.new(packages)
          end,
          T.nilable(QueryPackwerk::Packages)
        )
      end

      sig do
        params(
          query_params: T.untyped, # Array, or anything responding to `===`, which can't be typed
          query_fn: T.nilable(T.proc.params(arg0: T.untyped).returns(T::Boolean))
        ).returns(QueryPackwerk::Packages)
      end
      def where(**query_params, &query_fn)
        QueryPackwerk::Packages.new(super)
      end
    end

    sig { params(original_collection: T::Array[QueryPackwerk::Package]).void }
    def initialize(original_collection)
      @original_collection = original_collection
    end

    # You can query for packages rather than violations to get a broader view, and
    # the violations returned from this will be related to all packs in this class rather than just
    # one.
    sig { returns(QueryPackwerk::Violations) }
    def violations
      QueryPackwerk::Violations.new(
        @original_collection.flat_map { |pack| pack.violations.original_collection }
      )
    end

    sig { returns(String) }
    def inspect
      [
        "#<#{self.class.name} [",
        to_a.map(&:inspect).join("\n"),
        ']>'
      ].join("\n")
    end
  end
end
