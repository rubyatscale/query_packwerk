# typed: strict
# frozen_string_literal: true

require 'rubocop'

module QueryPackwerk
  class RuleRewriter
    # Abstract base class for source code transformation rules.
    # Extends the Parser::AST::Processor to provide common functionality
    # for traversing and modifying Ruby abstract syntax trees during
    # source rewriting operations.
    class BaseRule < Parser::AST::Processor
      include RuboCop::AST::Traversal

      ANONYMIZED = '_'

      def initialize(rewriter)
        @rewriter = rewriter

        super()
      end

      def create_range(begin_pos, end_pos)
        Parser::Source::Range.new(@rewriter.source_buffer, begin_pos, end_pos)
      end
    end
  end
end
