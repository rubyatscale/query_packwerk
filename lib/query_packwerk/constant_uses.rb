# typed: strict
# frozen_string_literal: true

require 'coderay'

module QueryPackwerk
  # The base of Violations and References, which are collections of ConstantUse
  # objects, with methods that group their sources by the constant they use,
  # and that say which packs use and define those constants.
  class ConstantUses
    extend T::Sig
    extend T::Generic
    extend T::Helpers

    abstract!

    Elem = type_member { { upper: QueryPackwerk::ConstantUse } }

    include Enumerable
    include QueryInterface

    sig { override.returns(T::Array[Elem]) }
    attr_reader :original_collection

    sig { returns(QueryPackwerk::FileCache) }
    attr_reader :file_cache

    sig do
      params(
        original_collection: T::Array[Elem],
        file_cache: QueryPackwerk::FileCache
      ).void
    end
    def initialize(original_collection, file_cache: QueryPackwerk::FileCache.new)
      @original_collection = original_collection
      @file_cache = file_cache

      @original_collection.each do |use|
        use.set_cache!(file_cache)
      end

      @cache_loaded = T.let(false, T::Boolean)
      @sources_loaded = T.let(false, T::Boolean)
    end

    sig { void }
    def load_cache!
      return true if @cache_loaded

      warn "Prepopulating AST cache with #{file_count} files: "
      start_time = Time.now

      @original_collection.each(&:load_cache!)

      finish_time = Time.now - start_time
      warn '', "AST cache loaded in #{finish_time}"
      @cache_loaded = true
    end

    sig { void }
    def load_sources!
      return true if @sources_loaded

      unless @cache_loaded
        load_cache!
        warn
      end

      warn "Prepopulating sources cache with #{count} #{self.class.name.to_s.split('::').last.to_s.downcase}: "
      start_time = Time.now

      total_sources_loaded = @original_collection.sum do |use|
        $stderr.print '.'
        use.sources.size
      end

      finish_time = Time.now - start_time
      warn "Loaded #{total_sources_loaded} full sources in #{finish_time}"

      @sources_loaded = true
    end

    sig { returns(Integer) }
    def file_count
      # Once for each file, which is parsed once however many uses are in it
      @original_collection.flat_map(&:files).uniq.size
    end

    sig { returns(T::Boolean) }
    def empty?
      @original_collection.empty?
    end

    sig { returns(T::Boolean) }
    def any?
      !empty?
    end

    # Gets all sources and their receiving chains grouped by the constant they use.
    sig { returns(T.untyped) }
    def raw_sources
      load_sources!

      deep_merge_groups(@original_collection) do |v|
        [v.class_name, v.sources]
      end
    end

    # Gets all sources and their receiving chains grouped by the constant they use.
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

    # Instead of returning all instances of the source, count how often each occurs, with the option to
    # provide a threshold to remove lower-occurring items.
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

      deep_merge_hash_groups(@original_collection) do |v|
        [v.class_name, v.sources_with_contexts(start_offset:, end_offset:)]
      end
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
    # "shape" of a method is called across a set of violations or references.
    sig { params(threshold: Integer).returns(T::Hash[String, T::Hash[String, Integer]]) }
    def anonymous_source_counts(threshold: 0)
      load_sources!

      deep_merge_counts(@original_collection, threshold:) { |v| [v.class_name, v.anonymous_source_counts] }
    end

    # Find which packs consume the constants these use
    sig { params(threshold: Integer).returns(T::Hash[String, Integer]) }
    def consumers(threshold: 0)
      tallies = @original_collection.map { |v| v.consuming_pack.name }.tally
      threshold_filter_sort(tallies, threshold:)
    end

    # Find which packs produce the constants these use
    sig { params(threshold: Integer).returns(T::Hash[String, Integer]) }
    def producers(threshold: 0)
      tallies = @original_collection.map { |v| v.producing_pack.name }.tally
      threshold_filter_sort(tallies, threshold:)
    end

    # Filter for those in files that match one of the provided file globs
    sig { params(file_globs: T.any(String, Regexp)).returns(T.self_type) }
    def including_files(*file_globs)
      filtered = @original_collection.select do |use|
        T.unsafe(use).includes_files?(*file_globs) # Sorbet hates splats
      end

      self.class.new(filtered, file_cache: @file_cache)
    end

    # Filter for those not in files that match one of the provided file globs
    sig { params(file_globs: T.any(String, Regexp)).returns(T.self_type) }
    def excluding_files(*file_globs)
      filtered = @original_collection.reject do |use|
        T.unsafe(use).includes_files?(*file_globs) # Sorbet hates splats
      end

      self.class.new(filtered, file_cache: @file_cache)
    end

    sig { returns(String) }
    def inspect
      arr = to_a.map(&:inspect)
      if arr.empty?
        "#<#{self.class.name} []>"
      else
        "#<#{self.class.name} [\n#{arr.join("\n")}\n]>"
      end
    end

    private

    sig { params(string: String).returns(String) }
    def highlight_ruby(string)
      CodeRay.encode(string, :ruby, :terminal)
    end
  end
end
