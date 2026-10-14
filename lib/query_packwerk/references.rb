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
        pack = ->(name) { packages[name] ||= package(name) }

        references = Pks.list_references.map do |reference|
          QueryPackwerk::Reference.new(
            constant_name: reference.fetch('constant_name'),
            file: reference.fetch('file'),
            line: reference.fetch('line'),
            column: reference.fetch('column'),
            producing_pack: pack.call(reference.fetch('defining_pack_name')),
            consuming_pack: pack.call(reference.fetch('referencing_pack_name')),
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
        # all's file cache, so a file is parsed once for every query until reload!
        QueryPackwerk::References.new(super(**query_params, &query_fn), file_cache: all.file_cache)
      end

      # Forgets the references, so the next query runs pks again
      sig { returns(NilClass) }
      def reload!
        @all = nil
      end

      private

      sig { params(name: String).returns(QueryPackwerk::Package) }
      def package(name)
        yml = Pathname.new(name).join(ParsePackwerk::PACKAGE_YML_NAME)
        # pks follows a symlink to a pack, where ParsePackwerk's default `**/` glob doesn't
        original_package = ParsePackwerk.find(name) || (ParsePackwerk::Package.from(yml) if yml.file?)
        raise Pks::Error, "pks lists references from or to #{name}, which has no package.yml" unless original_package

        QueryPackwerk::Package.new(original_package: original_package)
      end
    end
  end
end
