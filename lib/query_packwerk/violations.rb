# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # A collection class for managing and querying sets of Packwerk violations.
  # Provides aggregation, filtering, and analysis methods for violation data,
  # including source extraction, contextual reporting, and consumer relationship mapping.
  # Implements Enumerable and QueryInterface for flexible data manipulation.
  class Violations < ConstantUses
    extend T::Sig
    extend T::Generic

    Elem = type_member { { fixed: QueryPackwerk::Violation } }

    @all = T.let(nil, T.nilable(QueryPackwerk::Violations))

    class << self
      extend T::Sig

      # Get all violations from ParsePackwerk and wrap them in our own
      # representations. Unlike ParsePackwerk we also capture the destination
      # of the violation to give a bi-directional view of consumption.
      sig { returns(QueryPackwerk::Violations) }
      def all
        return @all if @all

        violations = ParsePackwerk.all.flat_map do |pack|
          pack.violations.map do |violation|
            QueryPackwerk::Violation.new(
              original_violation: violation,
              consuming_pack: pack
            )
          end
        end

        @all = QueryPackwerk::Violations.new(violations)
      end

      # Wrap the interface `where` with this type
      sig do
        params(
          query_params: T.untyped, # Array, or anything responding to `===`, which can't be typed
          query_fn: T.nilable(T.proc.params(arg0: T.untyped).returns(T::Boolean))
        ).returns(QueryPackwerk::Violations)
      end
      def where(**query_params, &query_fn)
        # all's file cache, so a file is parsed once for every query until reload!
        QueryPackwerk::Violations.new(super(**query_params, &query_fn), file_cache: all.file_cache)
      end

      sig { returns(NilClass) }
      def reload!
        @all = nil
      end
    end
  end
end
