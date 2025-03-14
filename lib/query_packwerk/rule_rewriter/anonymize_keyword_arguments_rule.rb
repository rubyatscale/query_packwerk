# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  class RuleRewriter
    class AnonymizeKeywordArgumentsRule < BaseRule
      def on_send(node)
        return unless node.arguments?

        node.arguments.select(&:hash_type?).each do |hash_node|
          hash_node.children.each do |pair|
            _keyword_node, value_node = if pair.kwsplat_type?
                                          [nil, pair.children.first]
                                        else
                                          pair.children
                                        end

            # Just in case we get strangely shaped nodes
            next unless value_node.respond_to?(:loc)

            @rewriter.replace(value_node.loc.expression, ANONYMIZED)
          end
        end
      end
    end
  end
end
