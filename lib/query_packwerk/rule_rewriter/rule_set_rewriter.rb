# typed: strict
# frozen_string_literal: true

require 'rubocop'
require_relative 'anonymize_arguments_rule'
require_relative 'anonymize_keyword_arguments_rule'

module QueryPackwerk
  class RuleRewriter
    # Coordinates the application of multiple rewriting rules to source code.
    # Processes Ruby code using RuboCop's source processing capabilities and
    # applies each configured rule in sequence to transform source code for
    # analysis purposes.
    class RuleSetRewriter
      attr_reader :source, :source_buffer, :ast

      RULES = [
        RuleRewriter::AnonymizeKeywordArgumentsRule,
        RuleRewriter::AnonymizeArgumentsRule
      ].freeze

      def initialize(string, rules: RULES)
        @source = processed_source(string)
        @ast = @source.ast
        @source_buffer = @source.buffer
        @rewriter = Parser::Source::TreeRewriter.new(@source_buffer)
        @rules = rules
      end

      def process
        @rules.each do |rule_class|
          rule = rule_class.new(@rewriter)
          @ast.each_node { |node| rule.process(node) }
        end

        @rewriter
          .process
          .delete("\n").squeeze(' ') # ...and multiple spaces, probably indents from above
          .gsub('( ', '(') # Remove paren spacing after previous
          .gsub(' )', ')') # Remove paren spacing after previous
          .gsub('. ', '.') # Remove suffix-dot spacing
      end

      private

      def processed_source(string)
        RuboCop::ProcessedSource.new(string, RUBY_VERSION.to_f)
      end
    end
  end
end
