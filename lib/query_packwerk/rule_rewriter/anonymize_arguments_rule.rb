# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  class RuleRewriter
    class AnonymizeArgumentsRule < BaseRule
      extend T::Sig

      # Arguments prefixed with a sigil like `*arg` and `&fn`
      SIGIL_ARGS = T.let(%i[splat block_pass].freeze, T::Array[Symbol])

      sig { override.params(node: RuboCop::AST::Node).void }
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
