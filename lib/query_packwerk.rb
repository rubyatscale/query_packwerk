# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'parse_packwerk'
require 'rubocop'

#
# QueryPackwerk is a tool for querying Packwerk violations.
#
# It is built on top of ParsePackwerk, and provides a Ruby-friendly API
# for querying package.yml and package_todo.yml files.
#
module QueryPackwerk
  autoload :Console, 'query_packwerk/console'
  autoload :QueryInterface, 'query_packwerk/query_interface'
  autoload :Violations, 'query_packwerk/violations'
  autoload :Violation, 'query_packwerk/violation'
  autoload :Packages, 'query_packwerk/packages'
  autoload :Package, 'query_packwerk/package'
  autoload :RuleRewriter, 'query_packwerk/rule_rewriter'
  autoload :FileCache, 'query_packwerk/file_cache'
  autoload :Version, 'query_packwerk/version'

  extend T::Sig
  # TODO: module_function isn't playing nicely with Sorbet
  extend self # rubocop:todo Style/ModuleFunction

  sig { params(name: String).returns(T.nilable(QueryPackwerk::Package)) }
  def package(name)
    Packages.where(name: name).first
  end

  # Get all violations where other packages access code from this package
  # (i.e., this package is the producer, others are consumers)
  sig { params(pack_name: String).returns(QueryPackwerk::Violations) }
  def violations_for(pack_name)
    QueryPackwerk::Violations.where(producing_pack: full_name(pack_name))
  end

  # Get all todos where this package accesses code from other packages
  # (i.e., this package is the consumer, others are producers)
  sig { params(pack_name: String).returns(QueryPackwerk::Violations) }
  def todos_for(pack_name)
    QueryPackwerk::Violations.where(consuming_pack: full_name(pack_name))
  end

  # Get where the violations occurred (where other packages access this package)
  sig { params(pack_name: String).returns(T::Hash[String, T::Array[String]]) }
  def violation_sources_for(pack_name)
    violations_for(pack_name).sources_with_locations
  end

  # Get how often the violations occurred
  sig { params(pack_name: String, threshold: Integer).returns(T::Hash[String, T::Hash[String, Integer]]) }
  def violation_counts_for(pack_name, threshold: 0)
    violations_for(pack_name).source_counts(threshold: threshold)
  end

  # Get the 'shape' of all violations (how other packages access this package)
  sig { params(pack_name: String).returns(T::Hash[String, T::Array[String]]) }
  def anonymous_violation_sources_for(pack_name)
    violations_for(pack_name).anonymous_sources
  end

  # Get how often each 'shape' of violation occurs (counts of how other packages access this package)
  sig { params(pack_name: String, threshold: Integer).returns(T::Hash[String, T::Hash[String, Integer]]) }
  def anonymous_violation_counts_for(pack_name, threshold: 0)
    violations_for(pack_name).anonymous_source_counts(threshold: threshold)
  end

  # Get which packages consume code from this package (who depends on this package)
  sig { params(pack_name: String, threshold: Integer).returns(T::Hash[String, Integer]) }
  def consumers(pack_name, threshold: 0)
    violations_for(pack_name).consumers(threshold: threshold)
  end

  # In case anyone is still using shorthand for pack names
  sig { params(pack_name: String).returns(String) }
  def full_name(pack_name)
    return pack_name if pack_name.match?(%r{\A(packs|components)/})

    "packs/#{pack_name}"
  end
end
