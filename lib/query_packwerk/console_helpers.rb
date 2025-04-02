# typed: true
# frozen_string_literal: true

module QueryPackwerk
  module ConsoleHelpers
    extend T::Sig
    include Kernel

    sig { returns(String) }
    def inspect
      'query_packwerk console'
    end

    sig { returns(NilClass) } # returning nil is less ugly in the console.
    def welcome
      help_query_packwerk
      puts
      help_help
    end

    sig { params(type: T.nilable(T.any(String, Symbol))).returns(NilClass) }
    def help(type = nil)
      case type.to_s.downcase
      when 'violation'
        help_violation
      when 'violations'
        help_violations
      when 'package'
        help_package
      when 'packages'
        help_packages
      when '', 'help'
        help_help
      else
        puts "Unknown help topic: #{type}\n"
        help_help
      end
    end

    sig { returns(NilClass) }
    def help_help
      puts <<~HELP
        Available help topics:
          help            # This help
          help_violation  # Help for QueryPackwerk::Violation
          help_violations # Help for QueryPackwerk::Violations
          help_package    # Help for QueryPackwerk::Package
          help_packages   # Help for QueryPackwerk::Packages
      HELP
    end

    sig { returns(NilClass) }
    def help_violation
      puts <<~HELP
        QueryPackwerk::Violation (lib/query_packwerk/violation.rb)
        ------------------------------------------------
        .type                   # Returns the violation type ('privacy' or 'dependency')
        .class_name             # Returns the violated constant name
        .files                  # Returns array of files containing the violation
        .producing_pack         # Returns the Package that owns the violated constant
        .consuming_pack         # Returns the Package that violated the constant
        .sources                # Returns array of AST nodes representing the violation occurrences
        .sources_with_locations # Returns array of [file:line, source] pairs for each violation
        .source_counts          # Returns hash of how often each violation source occurs
        .anonymous_sources      # Returns array of violation sources with arguments anonymized
        .anonymous_sources_with_locations # Returns array of [file:line, source] pairs for each violation with arguments anonymized
        .count                  # Returns total number of violation occurrences
      HELP
    end

    sig { returns(NilClass) }
    def help_violations
      puts <<~HELP
        QueryPackwerk::Violations (lib/query_packwerk/violations.rb)
        --------------------------------------------------
        .where(conditions)      # Returns new Violations filtered by conditions
        .raw_sources            # Returns hash of constant => AST nodes for all violations
        .sources                # Returns hash of constant => source strings for all violations
        .sources_with_locations # Returns hash of constant => [file:line, source] pairs
        .source_counts          # Returns hash of constant => {source => count} with occurrence counts
        .sources_with_contexts  # Returns hash of constant => [file:line, source] pairs for each violation with context
        .anonymous_sources      # Returns hash of constant => anonymized sources
        .anonymous_sources_with_locations # Returns array of [file:line, source] pairs for each violation with arguments anonymized
        .consumers(threshold)   # Returns hash of consuming package names and violation counts
        .producers(threshold)   # Returns hash of producing package names and violation counts
        .including_files(globs) # Returns new Violations filtered to include specific files
        .excluding_files(globs) # Returns new Violations filtered to exclude specific files
      HELP
    end

    sig { returns(NilClass) }
    def help_package
      puts <<~HELP
        QueryPackwerk::Package (lib/query_packwerk/package.rb)
        ----------------------------------------------
        .name                 # Returns the package name
        .enforce_dependencies # Returns whether package enforces dependencies
        .enforce_privacy      # Returns whether package enforces privacy
        .metadata             # Returns the package metadata from package.yml
        .config               # Returns the package configuration
        .dependencies         # Returns Packages collection of dependencies
        .dependency_names     # Returns array of dependency package names
        .owner                # Returns the package owner or 'Unowned'
        .directory            # Returns the package directory path
        .todos                # Returns Violations where this package is the consumer
        .violations           # Returns Violations where this package is the producer
        .consumers            # Returns Packages that consume this package
        .consumer_names       # Returns array of names of consuming packages
        .consumer_counts      # Returns hash of consumer package names and counts
      HELP
    end

    sig { returns(NilClass) }
    def help_packages
      puts <<~HELP
        QueryPackwerk::Packages (lib/query_packwerk/packages.rb)
        ------------------------------------------------
        .all                  # Returns all packages in the application
        .where(conditions)    # Returns new Packages filtered by conditions
        .violations           # Returns Violations for all packages in collection
      HELP
    end

    sig { returns(NilClass) }
    def help_query_packwerk
      puts <<~HELP
        QueryPackwerk (lib/query_packwerk.rb)
        ------------------------------
        Available commands:
          package(pack_name)                         # Get a package by name
          Packages.all                               # Get all packages

        Package Consumption (how others use this package):
          violations_for(pack_name)                  # Get all violations where others access this package
          violation_sources_for(pack_name)           # Get where others access this package
          violation_counts_for(pack_name)            # Get how often others access this package
          anonymous_violation_sources_for(pack_name) # Get the 'shape' of how others access this package
          anonymous_violation_counts_for(pack_name)  # Get how often each access pattern occurs
          consumers(pack_name)                       # Get which packages consume this package

        Package Dependencies (how this package uses others):
          todos_for(pack_name)                       # Get all todos where this package accesses others

        Violations.all                               # Get all violations
      HELP
    end
  end
end
