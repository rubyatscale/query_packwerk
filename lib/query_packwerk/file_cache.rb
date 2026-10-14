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

      # { file_name => { line => [AST const and send nodes that start on it] } }
      @line_cache = T.let({}, T::Hash[String, T::Hash[Integer, T::Array[RuboCop::AST::Node]]])

      @anonymized_args_cache = T.let({}, T::Hash[String, String])

      @is_active_record_cache = T.let({}, T::Hash[String, String])
      @is_constant_cache = T.let({}, T::Hash[String, String])
    end

    sig { params(file_names: String, headers: T::Boolean).void }
    def load!(*file_names, headers: true)
      file_count = file_names.size

      warn "Prepopulating AST cache with #{file_count} files: " if headers

      file_names.each do |f|
        # A dot for each file parsed, rather than for each use of one
        next if @file_ast_cache.key?(f)

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

        # The AST is also nil for source with no code, like a template that's only HTML.
        # `nil` stands in, as it has no constant or call that a reference's position could match.
        source.ast || ast_from('nil')
      end
    end

    sig { params(file_name: String).returns(String) }
    def get_file(file_name)
      @file_cache[file_name] ||= if (RUBY_FILE.match?(file_name) || ERB_FILE.match?(file_name)) && File.exist?(file_name)
                                   File.read(file_name)
                                 else
                                   ''
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
        # Not the `Foo` in `Foo::Bar`, which packwerk and pks count only as a use of `Foo::Bar`
        next false unless node.const_type? && !node.parent&.const_type?

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

    # Gets the full source of the reference that pks finds at a line and column.
    # pks counts the column in bytes, where the parser counts characters. A
    # reference that pks infers from an association, as `has_many :tacos` gives
    # `::Taco`, is at the call, so the call is its source.
    sig do
      params(file_name: String, line: Integer, column: Integer).returns(T.nilable(RuboCop::AST::Node))
    end
    def get_full_source_at(file_name:, line:, column:)
      source_line = get_file_ast(file_name).source_range.source_buffer.source_lines[line - 1]
      return unless source_line

      # Converted once, rather than for each node, as on a line with thousands of references
      character_column = source_line.byteslice(0, column).to_s.length
      nodes = nodes_by_line(file_name).fetch(line, []).select { |node| node.source_range.column == character_column }

      # The outermost constant, as `Foo::Bar` rather than the `Foo` in it
      node = nodes.find(&:const_type?) || nodes.find(&:send_type?)
      node && get_full_receiver_chain(node)
    end

    # Cleans up and anonymizes a source
    sig { params(source: String).returns(String) }
    def anonymize_arguments(source)
      @anonymized_args_cache[source] ||= RuleRewriter
                                         .rewrite(source)
                                         .delete("\n").squeeze(' ').delete_prefix('::')
    end

    private

    # Constants and calls by the line they start on, outermost first, as `each_node` visits them
    sig { params(file_name: String).returns(T::Hash[Integer, T::Array[RuboCop::AST::Node]]) }
    def nodes_by_line(file_name)
      @line_cache[file_name] ||= get_file_ast(file_name).each_node(:const, :send).group_by { |node| node.loc.line }
    end

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

      warn "Could not parse #{location}, so its sources are not included"
    end

    # Turns a string into a Ruby AST
    sig { params(string: String).returns(RuboCop::AST::Node) }
    def ast_from(string)
      processed_source(string).ast
    end

    # We can find a constant, but by going up its parents we can find the full call chain.
    # We check that each parent is a call on the child, giving us method calls and
    # arguments on a constant as well as where it occurred. The receiver must be the
    # child itself, not an equal node, as the first `Foo` is to the second in `Foo.bar(Foo)`.
    sig { params(node: RuboCop::AST::Node).returns(RuboCop::AST::Node) }
    def get_full_receiver_chain(node)
      return node unless node.const_type?

      current_node = T.let(node, RuboCop::AST::Node)

      while (parent_node = current_node.parent)
        break unless parent_node.call_type? && parent_node.receiver.equal?(current_node)

        current_node = parent_node
      end

      current_node
    end
  end
end
