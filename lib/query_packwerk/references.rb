# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # A collection of the references between packs that pks lists. It includes
  # the references that break none of the packs' rules, which package_todo.yml
  # files leave out, and has the same methods as Violations.
  class References < ConstantUses
    extend T::Sig
    extend T::Generic

    Elem = type_member { { fixed: QueryPackwerk::Reference } }

    @all = T.let(nil, T.nilable(QueryPackwerk::References))

    class << self
      extend T::Sig

      # Every reference from one pack to a constant that another pack defines.
      # The first call runs pks, which reads every file in the app.
      sig { returns(QueryPackwerk::References) }
      def all
        return @all if @all

        file_cache = QueryPackwerk::FileCache.new
        packages = T.let({}, T::Hash[String, QueryPackwerk::Package])

        references = Pks.list_references.map do |reference|
          QueryPackwerk::Reference.new(
            constant_name: reference.fetch('constant_name'),
            file: reference.fetch('file'),
            line: reference.fetch('line'),
            column: reference.fetch('column'),
            producing_pack: packages[reference.fetch('defining_pack_name')] ||= package(reference.fetch('defining_pack_name')),
            consuming_pack: packages[reference.fetch('referencing_pack_name')] ||= package(reference.fetch('referencing_pack_name')),
            violations: reference.fetch('violations').map do |violation|
              QueryPackwerk::Reference::Violation.new(
                type: violation.fetch('violation_type'),
                strict: violation.fetch('strict'),
                recorded: violation.fetch('recorded')
              )
            end,
            file_cache: file_cache
          )
        end

        @all = QueryPackwerk::References.new(references, file_cache: file_cache)
      end

      # Wrap the interface `where` with this type
      sig do
        params(
          query_params: T.untyped, # Array, or anything responding to `===`, which can't be typed
          query_fn: T.nilable(T.proc.params(arg0: T.untyped).returns(T::Boolean))
        ).returns(QueryPackwerk::References)
      end
      def where(**query_params, &query_fn)
        QueryPackwerk::References.new(super(**query_params, &query_fn))
      end

      # Forgets the references, so the next query runs pks again
      sig { void }
      def reload!
        @all = nil
      end

      private

      sig { params(name: String).returns(QueryPackwerk::Package) }
      def package(name)
        original_package = ParsePackwerk.find(name)
        raise Pks::Error, "pks lists references from or to #{name}, which has no package.yml that ParsePackwerk finds" unless original_package

        QueryPackwerk::Package.new(original_package: original_package)
      end
    end
  end
end
