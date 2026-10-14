# typed: strict
# frozen_string_literal: true

module QueryPackwerk
  # A reference from one pack to a constant that another pack defines, as pks
  # lists it, whether or not it breaks the packs' rules. Unlike a Violation,
  # which package_todo.yml records by file, it's at one place in one file, so
  # its source is the code there, except in ERB, where pks gives no place.
  class Reference < ConstantUse
    extend T::Sig

    # A rule of the packs that a reference breaks
    class Violation < T::Struct
      # dependency, privacy, visibility, layer or folder_privacy
      const :type, String

      # Whether the pack that enforces the rule is strict about it
      const :strict, T::Boolean

      # Whether a package_todo.yml records the violation. `pks check` fails on
      # one that isn't recorded.
      const :recorded, T::Boolean
    end

    sig { override.returns(QueryPackwerk::Package) }
    attr_reader :producing_pack

    sig { override.returns(QueryPackwerk::Package) }
    attr_reader :consuming_pack

    sig { returns(String) }
    attr_reader :file

    # Counted from 1, and nil in ERB, where pks keeps no source positions
    sig { returns(T.nilable(Integer)) }
    attr_reader :line

    # Counted in bytes from 0, and nil when line is
    sig { returns(T.nilable(Integer)) }
    attr_reader :column

    sig { returns(T::Array[QueryPackwerk::Reference::Violation]) }
    attr_reader :violations

    sig do
      params(
        constant_name: String,
        file: String,
        line: T.nilable(Integer),
        column: T.nilable(Integer),
        producing_pack: QueryPackwerk::Package,
        consuming_pack: QueryPackwerk::Package,
        violations: T::Array[QueryPackwerk::Reference::Violation],
        file_cache: QueryPackwerk::FileCache
      ).void
    end
    def initialize(
      constant_name:,
      file:,
      line:,
      column:,
      producing_pack:,
      consuming_pack:,
      violations:,
      file_cache: QueryPackwerk::FileCache.new
    )
      super(file_cache:)
      @constant_name = constant_name
      @file = file
      @line = line
      @column = column
      @producing_pack = producing_pack
      @consuming_pack = consuming_pack
      @violations = violations
    end

    # Fully qualified, as `::Foo::Bar`, though the code may name it
    # relatively, as `Bar` inside `module Foo`
    sig { override.returns(String) }
    def class_name
      @constant_name
    end
    alias constant_name class_name

    sig { override.returns(T::Array[String]) }
    def files
      [file]
    end

    # Whether the reference breaks none of the packs' rules
    sig { returns(T::Boolean) }
    def allowed?
      violations.empty?
    end

    sig { returns(T::Array[String]) }
    def violation_types
      violations.map(&:type)
    end

    # The types of the rules it breaks that no package_todo.yml records, which `pks check` reports
    sig { returns(T::Array[String]) }
    def unrecorded_violation_types
      violations.reject(&:recorded).map(&:type)
    end

    sig { returns(String) }
    def location
      line ? "#{file}:#{line}" : file
    end

    # The code at the reference's line and column. A reference that pks infers
    # from an association is at the call, as `has_many :tacos` is for `::Taco`.
    # In ERB, pks gives no position and lists a template's references to a
    # constant once, so they're wherever the template names it.
    sig { override.params(file_name: String).returns(T::Array[RuboCop::AST::Node]) }
    def full_sources_in(file_name)
      line = @line
      column = @column
      return @file_cache.get_full_sources(file_name: file_name, class_name: class_name) unless line && column

      [@file_cache.get_full_source_at(file_name: file_name, line: line, column: column)].compact
    end

    QUERY_KEYS = T.let(
      {
        constant_name: lambda(&:class_name),
        pack_name: ->(reference) { reference.producing_pack.name },
        file: lambda(&:file),

        # Which of the packs' rules the reference breaks, if any
        allowed: lambda(&:allowed?),
        violation_types: lambda(&:violation_types),
        privacy: ->(reference) { reference.violation_types.include?('privacy') },
        dependency: ->(reference) { reference.violation_types.include?('dependency') },

        # Which of those no package_todo.yml records
        unrecorded: ->(reference) { reference.unrecorded_violation_types.any? },
        unrecorded_violation_types: lambda(&:unrecorded_violation_types),

        # Which pack defines the constant, and which pack's code uses it
        consuming_pack: ->(reference) { reference.consuming_pack.name },
        producing_pack: ->(reference) { reference.producing_pack.name },

        producing_owner: ->(reference) { reference.producing_pack.owner },
        consuming_owner: ->(reference) { reference.consuming_pack.owner },

        # As for violations, "owner" is the producing pack's
        owner: ->(reference) { reference.producing_pack.owner },
        owned: ->(reference) { reference.producing_pack.owner != Packages::UNOWNED }
      }.freeze,
      T::Hash[Symbol, T.proc.params(arg0: QueryPackwerk::Reference).returns(T.untyped)]
    )

    sig { override.returns(T::Hash[Symbol, T.proc.params(arg0: QueryPackwerk::Reference).returns(T.untyped)]) }
    def query_keys
      QUERY_KEYS
    end

    sig { returns(String) }
    def inspect
      rules = allowed? ? 'allowed' : violation_types.join(', ')
      "#<#{self.class.name} #{consuming_pack.name} -> #{class_name} (#{rules}) at #{location}>"
    end
  end
end
