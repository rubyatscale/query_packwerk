# typed: strict
# frozen_string_literal: true

require 'coderay'

module QueryPackwerk
  # A collection class for managing and querying sets of Packwerk violations.
  # Provides aggregation, filtering, and analysis methods for violation data,
  # including source extraction, contextual reporting, and consumer relationship mapping.
  # Implements Enumerable and QueryInterface for flexible data manipulation.
  class Violations
    extend T::Sig
    extend T::Generic

    Elem = type_member { { fixed: QueryPackwerk::Violation } }

    include Enumerable
    include QueryInterface

    sig { override.returns(T::Array[QueryPackwerk::Violation]) }
    attr_reader :original_collection

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
        QueryPackwerk::Violations.new(super(**query_params, &query_fn))
      end
    end

    sig do
      params(
        original_collection: T::Array[QueryPackwerk::Violation],
        file_cache: QueryPackwerk::FileCache
      ).void
    end
    def initialize(original_collection, file_cache: QueryPackwerk::FileCache.new)
      @original_collection = original_collection
      @file_cache = T.let(file_cache, QueryPackwerk::FileCache)

      @original_collection.each do |violation|
        violation.set_cache!(file_cache)
      end

      @cache_loaded = T.let(false, T::Boolean)
      @sources_loaded = T.let(false, T::Boolean)
    end

    sig { void }
    def load_cache!
      return true if @cache_loaded

      puts "Prepopulating AST cache with #{file_count} files: "
      start_time = Time.now

      @original_collection.each(&:load_cache!)

      finish_time = Time.now - start_time
      puts '', "AST cache loaded in #{finish_time}"
      @cache_loaded = true
    end

    sig { void }
    def load_sources!
      return true if @sources_loaded

      unless @cache_loaded
        load_cache!
        puts
      end

      puts "Prepopulating sources cache with #{count} violations: "
      start_time = Time.now

      total_sources_loaded = @original_collection.sum do |violation|
        print '.'
        violation.sources.size
      end

      finish_time = Time.now - start_time
      puts "Loaded #{total_sources_loaded} full sources in #{finish_time}"

      @sources_loaded = true
    end

    sig { returns(Integer) }
    def file_count
      @original_collection.sum(&:file_count)
    end

    # Gets all sources and their receiving chains grouped by the constant they've violated.
    sig { returns(T.untyped) }
    def raw_sources
      load_sources!

      deep_merge_groups(@original_collection) do |v|
        [v.class_name, v.sources]
      end
    end

    # Gets all sources and their receiving chains grouped by the constant they've violated.
    sig { returns(T::Hash[String, T::Array[String]]) }
    def sources
      load_sources!

      deep_merge_groups(@original_collection) { |v| [v.class_name, v.sources.map(&:source)] }.transform_values(&:uniq)
    end

    # In addition to the above also provide the file location and line number along with the
    # source.
    sig { returns(T::Hash[String, T::Array[String]]) }
    def sources_with_locations
      load_sources!

      deep_merge_groups(@original_collection) { |v| [v.class_name, v.sources_with_locations] }
    end

    # Instead of getting all instances of the source, count how often each occurs, with the option to
    # provide a threshold to remove lower-occuring items.
    sig { params(threshold: Integer).returns(T::Hash[String, T::Hash[String, Integer]]) }
    def source_counts(threshold: 0)
      load_sources!

      deep_merge_counts(@original_collection, threshold:) { |v| [v.class_name, v.source_counts] }
    end

    # "Anonymize" the arguments of sources by replacing all arguments with underscores to get a look
    # at the "shape" of a function rather than its exact call (i.e. `test(1, 2, 3)` becomes `test(_, _, _)`).
    #
    # This also removes extra spacing, line-breaks, cbase constant sigils, and other extra information to
    # give a clearer view of a call's "shape".
    sig { returns(T::Hash[String, T::Array[String]]) }
    def anonymous_sources
      load_sources!

      deep_merge_groups(@original_collection) { |v| [v.class_name, v.anonymous_sources] }.transform_values(&:uniq)
    end

    sig { returns(T::Hash[String, T::Hash[String, T::Array[String]]]) }
    def anonymous_sources_with_locations
      load_sources!

      deep_merge_hash_groups(@original_collection) { |v| [v.class_name, v.anonymous_sources_with_locations] }
    end

    sig do
      params(start_offset: Integer, end_offset: Integer).returns(T::Hash[String, T::Hash[String, T::Array[String]]])
    end
    def sources_with_contexts(start_offset: 3, end_offset: 3)
      load_sources!

      deep_merge_hash_groups(@original_collection) { |v| [v.class_name, v.sources_with_contexts] }
    end

    sig { params(start_offset: Integer, end_offset: Integer).returns(String) }
    def sources_with_contexts_report(start_offset: 3, end_offset: 3)
      contexts = sources_with_contexts(start_offset:, end_offset:)
      output = +''

      contexts.each do |violated_constant, anonymized_sources|
        heavy_underline = '=' * violated_constant.size
        output << "#{violated_constant}\n#{heavy_underline}\n\n"

        anonymized_sources.each do |anonymized_source, full_contexts|
          light_underline = '-' * anonymized_source.size
          output << "#{anonymized_source}\n#{light_underline}\n\n"

          full_contexts.each do |context|
            output << highlight_ruby(context)
            output << "\n\n"
          end
        end
      end

      output
    end

    # Like the above source counts, but uses anonymized sources to give a clearer look at how often each
    # "shape" of a method is called across a set of violations.
    sig { params(threshold: Integer).returns(T::Hash[String, T::Hash[String, Integer]]) }
    def anonymous_source_counts(threshold: 0)
      load_sources!

      deep_merge_counts(@original_collection, threshold:) { |v| [v.class_name, v.anonymous_source_counts] }
    end

    # Find which packs consume these violations
    sig { params(threshold: Integer).returns(T::Hash[String, Integer]) }
    def consumers(threshold: 0)
      tallies = @original_collection.map { |v| v.consuming_pack.name }.tally
      threshold_filter_sort(tallies, threshold:)
    end

    # Filter for violations which include one of the provided file globs
    sig { params(file_globs: T.any(String, Regexp)).returns(QueryPackwerk::Violations) }
    def including_files(*file_globs)
      filtered_violations = @original_collection.select do |violation|
        T.unsafe(violation).includes_files?(*file_globs) # Sorbet hates splats
      end

      QueryPackwerk::Violations.new(filtered_violations)
    end

    # Filter for violations which do not include one of the provided file globs
    sig { params(file_globs: T.any(String, Regexp)).returns(QueryPackwerk::Violations) }
    def excluding_files(*file_globs)
      filtered_violations = @original_collection.reject do |violation|
        T.unsafe(violation).includes_files?(*file_globs) # Sorbet hates splats
      end

      QueryPackwerk::Violations.new(filtered_violations)
    end

    sig { returns(String) }
    def inspect
      [
        "#<#{self.class.name} [",
        to_a.map(&:inspect).join("\n"),
        ']>'
      ].join("\n")
    end

    private

    sig { params(string: String).returns(String) }
    def highlight_ruby(string)
      CodeRay.encode(string, :ruby, :terminal)
    end
  end
end
