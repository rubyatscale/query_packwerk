# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # A mixin module providing a flexible query interface for collections.
  # Implements methods for filtering, comparing, and manipulating collection data
  # with a consistent API pattern. Extends included classes with class methods
  # for advanced querying capabilities and integrates with Enumerable for
  # additional collection functionality.
  module QueryInterface
    include Kernel

    extend T::Sig
    extend T::Generic

    Elem = type_member

    include Enumerable

    # Iterate over every member of the underlying original collection,
    # also tie-in for Enumerable methods.
    #
    # Returns `T.untyped` because Sorbet complains on more accurate returns
    # or void.
    sig do
      override.params(
        block: T.nilable(T.proc.params(arg0: Elem).returns(T.untyped))
      ).returns(
        T.any(T::Enumerator[Elem], T::Array[Elem])
      )
    end
    def each(&block)
      return enum_for(:each) unless block_given?

      original_collection.each(&block)
    end

    # Should be overridden, the base of most of the queries.
    #
    # TODO: Consider refactoring to `abstract` interface
    sig { overridable.returns(T::Array[T.untyped]) }
    def original_collection
      []
    end

    # `Enumerable` does not expose these methods.
    sig { returns(Integer) }
    def size
      original_collection.size
    end

    alias length size
    alias count size

    # Extend the class with class extensions whenever this module is
    # included so we get both singleton and instance methods we need for
    # querying.
    sig { params(klass: T::Class[T.anything]).void }
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      include Kernel
      extend T::Sig

      # *Notes on Sorbet:*
      #
      # Allows you to query against the underlying collection. As Sorbet does not
      # allow for interface typing (i.e. `responds_to?`) we're using `T.untyped` instead.
      #
      # Since the implementing class will wrap the return value we also return `T.untyped` as
      # Sorbet will imply this should be a `T::Array[inheriting_class]` rather than `InheritingClass`.
      #
      # *Notes on Interface:*
      #
      # This is based on a pattern-matching like interface using `===` and a few other assumptions
      # about the underlying data structure. For singular values that means you can do this:
      #
      #     InheritingClass.where(name: /part_of_name/)
      #
      # ...as `===` works as a pattern inclusion for classes like `Regexp`, `Range`, class types, and
      # more.
      #
      # There are a few unique cases presumed here as well when dealing with more complex queries:
      #
      # * If both the underlying value and query value are arrays we check for intersection
      # * If the query value is an array we check if the underlying value "matches" and item in it
      # * If the underlying value is an array we check if the query value matches any part of it
      # * Otherwise we use `===` as a query
      #
      # These interfaces are meant to mimic ActiveRecord, but do take some liberties as we're working
      # with Ruby objects rather than underlying database structures.
      sig do
        params(
          query_params: T.untyped, # Array, or anything responding to `===`, which can't be typed
          _query_fn: T.nilable(T.proc.params(arg0: T.untyped).returns(T::Boolean))
        ).returns(T.untyped)
      end
      def where(**query_params, &_query_fn)
        query_keys = query_params.keys
        all_values = all

        accepted_keys = all_values.first.deconstruct_keys(nil).keys
        invalid_keys = query_keys - accepted_keys

        raise ArgumentError, "The following keys are invalid for querying: #{invalid_keys.join(", ")}" if invalid_keys.any?

        all_values.select do |value|
          next yield(value) if block_given?

          object_params = value.deconstruct_keys(query_keys)

          query_params.all? do |param, query_matcher|
            object_value = object_params[param]

            case [query_matcher, object_value]
            in [Array, Array]
              intersects?(query_matcher, object_value)
            in [Array, _]
              any_compare?(query_matcher, object_value)
            in [_, Array]
              includes?(query_matcher, object_value)
            else
              case_equal?(query_matcher, object_value)
            end
          end
        end
      end
      # Similar to the above `original_collection` we want to override this by defining
      # where the InheritingClass can find all of its raw data.
      #
      # Sorbet does not recognize `included(klass)`/`klass.extend(ClassMethods)` when
      # looking for `override` hooks. May be a bug in Sorbet.
      sig do
        returns(T.untyped)
      end
      def all
        []
      end

      private

      # Query Array to value Array is intersection, rather than strict equality or a literal pattern
      # match. While we could do a `===` approximation of intersection that would make
      # the code much more complicated.
      sig { params(query_matcher: T::Array[T.untyped], object_value: T::Array[T.untyped]).returns(T::Boolean) }
      def intersects?(query_matcher, object_value)
        (query_matcher & object_value).any?
      end

      # Query Array to Any object value checks if any of the query matchers match that value
      sig { params(query_matcher: T::Array[T.untyped], object_value: T.untyped).returns(T::Boolean) }
      def any_compare?(query_matcher, object_value)
        query_matcher.any? { |matcher| matcher === object_value } # rubocop:disable Style/CaseEquality
      end

      # Any other type of Query to Array is find if any value matches the condition
      sig { params(query_matcher: T.untyped, object_value: T::Array[T.untyped]).returns(T::Boolean) }
      def includes?(query_matcher, object_value)
        object_value.any? { |v| query_matcher === v } # rubocop:disable Style/CaseEquality
      end

      # Otherwise we use `===` to decide if it's a match, and we use it explicitly as
      # it's a very powerful query-like DSL and is in the language for a reason.
      #
      # We would use `===` for all cases, except that `Array` does not define it, nor
      # should it as it could be defined in multiple different ways much the same as
      # `String#each` could mean several things.
      sig { params(query_matcher: T.untyped, object_value: T.untyped).returns(T::Boolean) }
      def case_equal?(query_matcher, object_value)
        query_matcher === object_value # rubocop:disable Style/CaseEquality
      end
    end

    protected

    sig do
      params(
        collection: T::Array[T.untyped],
        threshold: Integer,
        _blk: T.proc.params(arg0: T.untyped).returns(T::Array[T.untyped])
      ).returns(T::Hash[String, T::Hash[String, Integer]])
    end
    def deep_merge_counts(collection, threshold: 0, &_blk)
      nested_counts = collection.each_with_object(
        Hash.new { |h, k| h[k] = Hash.new(0) }
      ) do |violation, new_nested_counts|
        key, values = yield(violation)

        new_nested_counts[key].merge!(values) { |_k, a, b| a + b }
      end

      threshold_drop(nested_counts, threshold: threshold)
    end

    sig do
      params(
        collection: T::Array[T.untyped],
        _blk: T.proc.params(arg0: T.untyped).returns(T::Array[T.untyped])
      ).returns(T::Hash[String, T::Array[T.untyped]])
    end
    def deep_merge_groups(collection, &_blk)
      groups = collection.each_with_object(
        Hash.new { |h, k| h[k] = [] }
      ) do |violation, new_groups|
        key, values = yield(violation)
        new_groups[key].concat(values)
      end

      if groups.values.first.is_a?(String)
        groups.transform_values(&:sort)
      else
        groups
      end
    end

    sig do
      params(
        collection: T::Array[T.untyped],
        _blk: T.proc.params(arg0: T.untyped).returns(T::Array[T.untyped])
      ).returns(T::Hash[String, T::Hash[String, T::Array[String]]])
    end
    def deep_merge_hash_groups(collection, &_blk)
      initial_hash = Hash.new do |constants, const_name|
        constants[const_name] = Hash.new do |sources, source|
          sources[source] = []
        end
      end

      merged_collection = collection.each_with_object(initial_hash) do |violation, new_groups|
        constant_name, sources = yield(violation)
        sources.each do |source, file_locations|
          new_groups[constant_name][source].concat(file_locations)
        end
      end

      merged_collection.transform_values do |sources_hash|
        sources_hash
          .transform_values(&:sort)
          .sort_by { |_anonymous_source, file_list| -file_list.size }
          .to_h
      end
    end

    sig do
      params(
        hash: T::Hash[String, T::Hash[String, Integer]],
        threshold: Integer
      ).returns(T::Hash[String, T::Hash[String, Integer]])
    end
    def threshold_drop(hash, threshold: 0)
      hash
        .transform_values { |vs| threshold_filter_sort(vs, threshold: threshold) }
        .reject { |_k, vs| vs.empty? }
    end

    sig { params(hash: T::Hash[String, Integer], threshold: Integer).returns(T::Hash[String, Integer]) }
    def threshold_filter_sort(hash, threshold: 0)
      hash
        .select { |_k, v| v >= threshold }
        .sort_by { |_k, v| -v }
        .to_h
    end

    mixes_in_class_methods(ClassMethods)
  end
end
