# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # Represents a single Packwerk violation with extended inspection capabilities.
  # Provides methods to analyze violation details including source location, contextual
  # information, and code patterns. Facilitates both detailed and anonymized views of
  # dependency violations between packages.
  class Violation
    extend T::Sig

    # This does not play nicely with ERB files which may have violations
    RUBY_FILE = T.let(/\.(rb|rake)\z/, Regexp)
    ALL_CAPS = T.let(/\A[A-Z_]+\z/, Regexp)

    sig { returns(QueryPackwerk::Package) }
    attr_reader :producing_pack

    sig { returns(QueryPackwerk::Package) }
    attr_reader :consuming_pack

    sig do
      params(
        original_violation: ParsePackwerk::Violation,
        consuming_pack: ParsePackwerk::Package,
        file_cache: QueryPackwerk::FileCache
      ).void
    end
    def initialize(original_violation:, consuming_pack:, file_cache: QueryPackwerk::FileCache.new)
      @original_violation = original_violation

      @producing_pack = T.let(
        QueryPackwerk::Package.new(original_package: T.must(ParsePackwerk.find(original_violation.to_package_name))),
        QueryPackwerk::Package
      )

      @consuming_pack = T.let(
        QueryPackwerk::Package.new(original_package: consuming_pack),
        QueryPackwerk::Package
      )

      @file_cache = T.let(file_cache, QueryPackwerk::FileCache)
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
      @cache_loaded = false
      @file_cache = cache
    end

    sig { returns(Integer) }
    def file_count
      files.size
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

    sig { returns(String) }
    def class_name
      @original_violation.class_name
    end

    sig { returns(T::Array[String]) }
    def files
      @original_violation.files
    end

    # Addon methods

    # Whether or not the files containing violations match any provided globs
    #
    # See also: https://ruby-doc.org/core-2.7.6/File.html#method-c-fnmatch
    sig { params(globs: T.any(String, Regexp)).returns(T::Boolean) }
    def includes_files?(*globs)
      globs.any? do |glob|
        files.any? do |file_name|
          glob.is_a?(Regexp) ? glob.match?(file_name) : File.fnmatch?(glob, file_name)
        end
      end
    end

    # All sources and their receiver chains across all files this violation covers
    sig { returns(T::Array[RuboCop::AST::Node]) }
    def sources
      load_cache!

      files.flat_map do |file_name|
        @file_cache.get_full_sources(file_name: file_name, class_name: class_name)
      end
    end

    # Adds additional file and line number information to each source
    sig { returns(T::Array[T.any(String, T::Array[RuboCop::AST::Node])]) }
    def sources_with_locations
      load_cache!

      files.flat_map do |file_name|
        @file_cache
          .get_full_sources(file_name: file_name, class_name: class_name)
          .map { |s| ["#{file_name}:#{s.loc.line}", s.source] }
      end
    end

    # Frequency of which each source occurs
    sig { returns(T::Hash[String, Integer]) }
    def source_counts
      load_cache!

      sources = files.flat_map do |file_name|
        @file_cache
          .get_full_sources(file_name: file_name, class_name: class_name)
          .map(&:source)
      end

      sources.tally
    end

    # Sources that have had their arguments anonymized
    sig { returns(T::Array[String]) }
    def anonymous_sources
      load_cache!

      files.flat_map do |file_name|
        @file_cache
          .get_full_anonymous_sources(file_name: file_name, class_name: class_name)
      end
    end

    # sig { returns(T::Array[T.any(String, T::Array[String])]) }
    sig { returns(T.untyped) }
    def anonymous_sources_with_locations
      load_cache!

      file_sources = files.flat_map do |file_name|
        @file_cache.get_full_sources(file_name: file_name, class_name: class_name).map do |s|
          ["#{file_name}:#{s.loc.line}", @file_cache.anonymize_arguments(s.source)]
        end
      end

      anonymous_source_groups = Hash.new { |h, source| h[source] = [] }

      file_sources.each_with_object(anonymous_source_groups) do |(location, source), groups|
        groups[source] << location
      end
    end

    sig { params(start_offset: Integer, end_offset: Integer).returns(T.untyped) }
    def sources_with_contexts(start_offset: 3, end_offset: 3)
      load_cache!

      file_sources = files.flat_map do |file_name|
        @file_cache.get_full_sources(file_name: file_name, class_name: class_name).map do |s|
          line_number = s.loc.line
          start_pos = line_number - start_offset
          end_pos = line_number + end_offset

          location = "#{file_name}:#{s.loc.line} (L#{start_pos}..#{end_pos})"
          context = @file_cache.get_file(file_name).lines.slice(start_pos..end_pos)
          full_context = unindent((context || ['']).join)

          [@file_cache.anonymize_arguments(s.source), "> #{location}\n\n#{full_context}"]
        end
      end

      anonymous_source_groups = Hash.new { |h, source| h[source] = [] }

      file_sources.each_with_object(anonymous_source_groups) do |(anonymous_source, full_source), groups|
        groups[anonymous_source] << full_source
      end
    end

    # Like above frequency of sources, except by method "shape" rather than
    # exact arguments
    sig { returns(T::Hash[String, Integer]) }
    def anonymous_source_counts
      anonymous_sources.tally
    end

    # True count of violations, as there can be multiple of the same violation
    # in a file.
    sig { returns(Integer) }
    def count
      files.sum do |file_name|
        @file_cache.get_all_const_occurrences(
          file_name: file_name,
          class_name: class_name
        ).size
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
          value: constant.is_a?(Class) && constant < ApplicationRecord
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

      # all_values[:is_active_record] = active_record? if !keys || keys.include?(:is_active_record)
      # all_values[:is_constant] = active_record? if !keys || keys.include?(:is_constant)

      keys.nil? ? all_values : all_values.slice(*T.unsafe(keys))
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
