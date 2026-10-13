# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # Manages caching of file contents, AST nodes, and code analysis results.
  # Provides efficient access to parsed Ruby code, constant references, and
  # source abstractions for performance optimization during violation analysis.
  # Supports both standard and anonymized views of source code patterns.
  class FileCache
    extend T::Sig

    # The files packwerk parses as Ruby, from Packwerk::Parsers::Factory
    RUBY_FILE = /(\.(rb|rake|builder|gemspec|ru)|Gemfile|Rakefile)\z/
    ERB_FILE = /\.erb\z/

    sig { void }
    def initialize
      # { file_name => AST }
      @file_ast_cache = T.let({}, T::Hash[String, RuboCop::AST::Node])
      @file_cache = T.let({}, T::Hash[String, String])

      # { [file_name, const_name] => [AST const nodes] }
      @file_const_cache = T.let({}, T::Hash[T::Array[String], T::Array[RuboCop::AST::Node]])

      # { [file_name, const_name] => [AST const nodes with full receiver chains] }
      @full_source_cache = T.let({}, T::Hash[T::Array[String], T::Array[RuboCop::AST::Node]])

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
      @file_ast_cache[file_name] ||= begin
        source = processed_source(ruby_source(file_name))
        warn_unparseable(file_name, source) unless source.valid_syntax?

        # The AST is also nil for source with no code, like a template that's only HTML
        source.ast || ast_from('x')
      end
    end

    sig { params(file_name: String).returns(String) }
    def get_file(file_name)
      @file_cache[file_name] ||= if (RUBY_FILE.match?(file_name) || ERB_FILE.match?(file_name)) && File.exist?(file_name)
                                   File.read(file_name)
                                 else
                                   'x'
                                 end
    end

    # Get all occurrences of the violation's constant in a file
    sig { params(file_name: String, class_name: String).returns(T::Array[RuboCop::AST::Node]) }
    def get_all_const_occurrences(file_name:, class_name:)
      const_key = [file_name, class_name]

      return T.must(@file_const_cache[const_key]) if @file_const_cache.key?(const_key)

      absolute_const_node = ast_from(class_name)
      relative_const_node = ast_from(class_name.delete_prefix('::'))

      @file_const_cache[const_key] = get_file_ast(file_name).each_node.select do |node|
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

    private

    # Blanks out everything in an ERB template except its Ruby code, so line numbers still match the template
    sig { params(file_name: String).returns(String) }
    def ruby_source(file_name)
      source = get_file(file_name)
      return source unless ERB_FILE.match?(file_name)

      Herb.extract_ruby(source, semicolons: true, comments: false, preserve_positions: true)
    end

    sig { params(string: String).returns(RuboCop::ProcessedSource) }
    def processed_source(string)
      RuboCop::ProcessedSource.new(string, RUBY_VERSION.to_f)
    end

    sig { params(file_name: String, source: RuboCop::ProcessedSource).void }
    def warn_unparseable(file_name, source)
      error = source.diagnostics.find { |diagnostic| diagnostic.level == :error }
      location = error ? "#{file_name}:#{error.location.line} (#{error.message})" : file_name

      warn "Could not parse #{location}, so its violations are not included"
    end

    # Turns a string into a Ruby AST
    sig { params(string: String).returns(RuboCop::AST::Node) }
    def ast_from(string)
      processed_source(string).ast
    end

    # We can find a constant, but by going up its parents we can find the full call chain.
    # We check if each parent is a receiver of the child, giving us method calls and
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
