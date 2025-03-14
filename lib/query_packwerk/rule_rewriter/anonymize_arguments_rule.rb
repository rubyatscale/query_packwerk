# typed: strict
# frozen_string_literal: true

require_relative "base_rule"

module QueryPackwerk
  class RuleRewriter
    class AnonymizeArgumentsRule < BaseRule
      # Arguments prefixed with a sigil like `*arg` and `&fn`
      SIGIL_ARGS = %i[splat block_pass].freeze

      def on_send(node)
        return unless node.arguments?

        node.arguments.reject(&:hash_type?).each do |arg|
          arg_node = if SIGIL_ARGS.include?(arg.type)
                       arg.children.first
                     else
                       arg
                     end

          # Just in case we get strangely shaped nodes
          next unless arg_node.respond_to?(:loc)

          @rewriter.replace(arg_node.loc.expression, ANONYMIZED)
        end
      end
    end
  end
end
