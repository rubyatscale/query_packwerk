# typed: strict
# frozen_string_literal: true

require_relative 'rule_rewriter/rule_set_rewriter'
require_relative 'rule_rewriter/base_rule'
require_relative 'rule_rewriter/anonymize_arguments_rule'
require_relative 'rule_rewriter/anonymize_keyword_arguments_rule'

module QueryPackwerk
  # Orchestrates source code rewriting using defined transformation rules.
  # Provides an entry point for applying rule-based code transformations,
  # particularly for anonymizing method arguments and source patterns
  # to facilitate pattern-based violation analysis.
  class RuleRewriter
    def self.rewrite(source_string)
      RuleSetRewriter.new(source_string).process
    end
  end
end
