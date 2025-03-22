# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # Orchestrates source code rewriting using defined transformation rules.
  # Provides an entry point for applying rule-based code transformations,
  # particularly for anonymizing method arguments and source patterns
  # to facilitate pattern-based violation analysis.
  class RuleRewriter
    autoload :BaseRule, 'query_packwerk/rule_rewriter/base_rule'
    autoload :RuleSetRewriter, 'query_packwerk/rule_rewriter/rule_set_rewriter'
    autoload :AnonymizeArgumentsRule, 'query_packwerk/rule_rewriter/anonymize_arguments_rule'
    autoload :AnonymizeKeywordArgumentsRule, 'query_packwerk/rule_rewriter/anonymize_keyword_arguments_rule'

    extend T::Sig

    sig { params(source_string: String).returns(String) }
    def self.rewrite(source_string)
      RuleSetRewriter.new(source_string).process
    end
  end
end
