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

  # All violations for a pack
  sig { params(pack_name: String).returns(QueryPackwerk::Violations) }
  def violations_for(pack_name)
    QueryPackwerk::Violations.where(producing_pack: full_name(pack_name))
  end

  # Where the violations occurred
  sig { params(pack_name: String).returns(T::Hash[String, T::Array[String]]) }
  def violation_sources_for(pack_name)
    violations_for(pack_name).sources_with_locations
  end

  # How often the violations occurred
  sig { params(pack_name: String, threshold: Integer).returns(T::Hash[String, T::Hash[String, Integer]]) }
  def violation_counts_for(pack_name, threshold: 0)
    violations_for(pack_name).source_counts(threshold: threshold)
  end

  # The "shape" of all of the occurring violations
  sig { params(pack_name: String).returns(T::Hash[String, T::Array[String]]) }
  def anonymous_violation_sources_for(pack_name)
    violations_for(pack_name).anonymous_sources
  end

  # How often each of those shapes occurs
  sig { params(pack_name: String, threshold: Integer).returns(T::Hash[String, T::Hash[String, Integer]]) }
  def anonymous_violation_counts_for(pack_name, threshold: 0)
    violations_for(pack_name).anonymous_source_counts(threshold: threshold)
  end

  # Who consumes this pack?
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
