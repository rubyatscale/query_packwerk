# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # Manages caching of file contents, AST nodes, and code analysis results.
  # Provides efficient access to parsed Ruby code, constant references, and
  # source abstractions for performance optimization during violation analysis.
  # Supports both standard and anonymized views of source code patterns.
  class FileCache
    extend T::Sig

    RUBY_FILE = T.let(/\.(rb|rake)\z/, Regexp)

    sig { void }
    def initialize
      # { file_name => AST }
      @file_ast_cache = T.let({}, T::Hash[String, RuboCop::AST::Node])
      @file_cache = T.let({}, T::Hash[String, String])

      # { [file_name, const_name] => [AST const nodes] }
      @file_const_cache = T.let({}, T::Hash[T::Array[String], T::Array[RuboCop::AST::Node]])

      # { [file_name, const_name] => [AST const nodes with full receiver chains] }
      @full_source_cache = T.let({}, T::Hash[T::Array[String], T::Array[RuboCop::AST::Node]])

      # { [file_name, const_name] => [anonymized sources] }
      @anonymized_source_cache = T.let({}, T::Hash[T::Array[String], T::Array[String]])

      @anonymized_args_cache = T.let({}, T::Hash[String, String])

      @is_active_record_cache = T.let({}, T::Hash[String, String])
      @is_constant_cache = T.let({}, T::Hash[String, String])
    end

    sig { params(file_names: String, headers: T::Boolean).void }
    def load!(*file_names, headers: true)
      file_count = file_names.size

      warn "Prepopulating AST cache with #{file_count} files: " if headers

      file_names.each do |f|
        get_file_ast(f)
        $stderr.print '.'
      end

      warn '', 'AST cache loaded' if headers
    end

    sig { params(cache_name: Symbol, key: T.untyped, value: T.untyped).returns(T.untyped) }
    def set(cache_name, key:, value:)
      case cache_name
      when :is_active_record
        return @is_active_record_cache[key] if @is_active_record_cache.key?(key)

        @is_active_record_cache[key] = value
      when :is_constant
        return @is_constant_cache[key] if @is_constant_cache.key?(key)

        @is_constant_cache[key] = value
      end
    end

    sig { params(file_name: String).returns(RuboCop::AST::Node) }
    def get_file_ast(file_name)
      @file_ast_cache[file_name] ||= ast_from(get_file(file_name))
    end

    sig { params(file_name: String).returns(String) }
    def get_file(file_name)
      @file_cache[file_name] ||= if RUBY_FILE.match?(file_name) && File.exist?(file_name)
                                   File.read(file_name)
                                 else
                                   'x'
                                 end
    end

    # Get all occurrencs of the violation's constant in a file
    sig { params(file_name: String, class_name: String).returns(T::Array[RuboCop::AST::Node]) }
    def get_all_const_occurrences(file_name:, class_name:)
      const_key = [file_name, class_name]

      return T.must(@file_const_cache[const_key]) if @file_const_cache.key?(const_key)

      absolute_const_node = ast_from(class_name)
      relative_const_node = ast_from(class_name.delete_prefix('::'))

      @file_const_cache[const_key] = get_file_ast(file_name).each_descendant.select do |node|
        next false unless node.const_type?

        node == absolute_const_node || node == relative_const_node
      end
    end

    # Gets the full unanonymized source of how a constant is called
    sig { params(file_name: String, class_name: String).returns(T::Array[RuboCop::AST::Node]) }
    def get_full_sources(file_name:, class_name:)
      const_key = [file_name, class_name]

      return T.must(@full_source_cache[const_key]) if @full_source_cache.key?(const_key)

      @full_source_cache[const_key] = get_all_const_occurrences(
        file_name: file_name,
        class_name: class_name
      ).map do |node|
        get_full_receiver_chain(node)
      end
    end

    # Cleans up and anonymizes a source
    sig { params(source: String).returns(String) }
    def anonymize_arguments(source)
      @anonymized_args_cache[source] ||= RuleRewriter
                                         .rewrite(source)
                                         .delete("\n").squeeze(' ').delete_prefix('::')
    end

    # Get the full receiver chains on a constant, and anonymize their arguments
    sig { params(file_name: String, class_name: String).returns(T::Array[String]) }
    def get_full_anonymous_sources(file_name:, class_name:)
      const_key = [file_name, class_name]

      return T.must(@anonymized_source_cache[const_key]) if @anonymized_source_cache.key?(const_key)

      @anonymized_source_cache[const_key] = get_full_sources(
        file_name: file_name,
        class_name: class_name
      ).map do |node|
        get_full_receiver_chain(node)
          .source
          .then { |s| anonymize_arguments(s) }
      end
    end

    private

    # Turns a string into a Ruby AST
    sig { params(string: String).returns(RuboCop::AST::Node) }
    def ast_from(string)
      RuboCop::ProcessedSource.new(string, RUBY_VERSION.to_f).ast
    end

    # We can find a constant, but by going up its parents we can find out the full call chain
    # by checking if each parent is a receiver of the child, giving us method calls and
    # arguments on a constant as well as where it occurred.
    sig { params(node: RuboCop::AST::Node).returns(RuboCop::AST::Node) }
    def get_full_receiver_chain(node)
      return node unless node.const_type?

      current_node = T.let(node, RuboCop::AST::Node)

      while (parent_node = current_node.parent)
        break unless parent_node.receiver == current_node

        current_node = parent_node
      end

      current_node
    end
  end
end
