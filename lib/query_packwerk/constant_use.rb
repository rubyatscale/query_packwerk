# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # A pack's use of a constant that another pack defines, such as a Violation
  # or a Reference. Shows the code that uses the constant: its sources, each the
  # constant with any calls chained on it. Subclasses say which files the code
  # is in and how to find the sources in each.
  class ConstantUse
    extend T::Sig
    extend T::Helpers

    abstract!

    ALL_CAPS = /\A[A-Z_]+\z/

    sig { abstract.returns(String) }
    def class_name; end

    sig { abstract.returns(T::Array[String]) }
    def files; end

    sig { abstract.returns(QueryPackwerk::Package) }
    def producing_pack; end

    sig { abstract.returns(QueryPackwerk::Package) }
    def consuming_pack; end

    # The sources in one of the files, with the calls chained on each
    sig { abstract.params(file_name: String).returns(T::Array[RuboCop::AST::Node]) }
    def full_sources_in(file_name); end

    sig { params(file_cache: QueryPackwerk::FileCache).void }
    def initialize(file_cache:)
      @file_cache = file_cache
      @cache_loaded = T.let(false, T::Boolean)
    end

    sig { params(headers: T::Boolean).void }
    def load_cache!(headers: false)
      return true if @cache_loaded

      @file_cache.load!(*T.unsafe(files), headers: headers)
      @cache_loaded = true
    end

    sig { params(cache: QueryPackwerk::FileCache).void }
    def set_cache!(cache)
      # Each query sets the cache again, and a cache it already has is still loaded
      return if cache.equal?(@file_cache)

      @cache_loaded = false
      @file_cache = cache
    end

    sig { returns(Integer) }
    def file_count
      files.size
    end

    # Whether or not any of its files match any provided globs
    #
    # See Ruby documentation for File.fnmatch for more details.
    sig { params(globs: T.any(String, Regexp)).returns(T::Boolean) }
    def includes_files?(*globs)
      globs.any? do |glob|
        files.any? do |file_name|
          glob.is_a?(Regexp) ? glob.match?(file_name) : File.fnmatch?(glob, file_name)
        end
      end
    end

    # All sources and their receiver chains across all of its files
    sig { returns(T::Array[RuboCop::AST::Node]) }
    def sources
      load_cache!

      files.flat_map do |file_name|
        full_sources_in(file_name)
      end
    end

    # Adds additional file and line number information to each source
    sig { returns(T::Array[[String, String]]) }
    def sources_with_locations
      load_cache!

      files.flat_map do |file_name|
        full_sources_in(file_name).map { |s| ["#{file_name}:#{s.loc.line}", s.source] }
      end
    end

    # Frequency of which each source occurs
    sig { returns(T::Hash[String, Integer]) }
    def source_counts
      load_cache!

      sources = files.flat_map do |file_name|
        full_sources_in(file_name).map(&:source)
      end

      sources.tally
    end

    # Sources that have had their arguments anonymized
    sig { returns(T::Array[String]) }
    def anonymous_sources
      load_cache!

      files.flat_map do |file_name|
        full_sources_in(file_name).map { |s| @file_cache.anonymize_arguments(s.source) }
      end
    end

    sig { returns(T::Hash[String, T::Array[String]]) }
    def anonymous_sources_with_locations
      load_cache!

      file_sources = files.flat_map do |file_name|
        full_sources_in(file_name).map do |s|
          ["#{file_name}:#{s.loc.line}", @file_cache.anonymize_arguments(s.source)]
        end
      end

      anonymous_source_groups = Hash.new { |h, source| h[source] = [] }

      file_sources.each_with_object(anonymous_source_groups) do |(location, source), groups|
        groups[source] << location
      end
    end

    sig { params(start_offset: Integer, end_offset: Integer).returns(T::Hash[String, T::Array[String]]) }
    def sources_with_contexts(start_offset: 3, end_offset: 3)
      load_cache!

      file_sources = files.flat_map do |file_name|
        lines = @file_cache.get_file(file_name).lines

        full_sources_in(file_name).map do |s|
          line_number = s.loc.line
          start_pos = [line_number - start_offset, 1].max
          end_pos = [line_number + end_offset, lines.size].min

          location = "#{file_name}:#{s.loc.line} (L#{start_pos}..#{end_pos})"
          context = lines[(start_pos - 1)...end_pos]
          full_context = unindent((context || ['']).join)

          [@file_cache.anonymize_arguments(s.source), "> #{location}\n\n#{full_context}"]
        end
      end

      anonymous_source_groups = Hash.new { |h, source| h[source] = [] }

      file_sources.each_with_object(anonymous_source_groups) do |(anonymous_source, full_source), groups|
        groups[anonymous_source] << full_source
      end
    end

    # Like the above source frequency, except grouped by method "shape" rather than
    # exact arguments
    sig { returns(T::Hash[String, Integer]) }
    def anonymous_source_counts
      anonymous_sources.tally
    end

    # True count of uses, as a file can use the constant more than once.
    sig { returns(Integer) }
    def count
      files.sum do |file_name|
        full_sources_in(file_name).size
      end
    end

    sig do
      params(keys: T.nilable(T::Array[Symbol])).returns(T::Hash[Symbol, T.untyped])
    end
    def runtime_keys(keys)
      return {} unless defined?(Rails)

      runtime_values = {}

      return { is_active_record: false, is_constant: false } unless Kernel.const_defined?(class_name)

      if keys.nil? || keys.include?(:is_active_record)
        constant = Kernel.const_get(class_name) # rubocop:disable Sorbet/ConstantsFromStrings

        value = @file_cache.set(
          :is_active_record,
          key: class_name,
          # Class#< gives nil, not false, for a class that isn't related
          value: constant.is_a?(Class) && (constant < ApplicationRecord || false)
        )

        runtime_values[:is_active_record] = value
      end

      if keys.nil? || keys.include?(:is_constant)
        value = @file_cache.set(
          :is_constant,
          key: class_name,
          value: class_name.split('::').last&.match?(ALL_CAPS)
        )

        runtime_values[:is_constant] = value
      end

      runtime_values
    end

    private

    sig { params(string: String).returns(String) }
    def unindent(string)
      # Multi-line match, this is intentional
      min_space = string.scan(/^\s*/).min_by(&:length)
      string.gsub(/^#{min_space}/, '')
    end
  end
end
