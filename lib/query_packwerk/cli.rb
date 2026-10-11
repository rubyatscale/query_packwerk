# typed: strict
# frozen_string_literal: true

require 'thor'

module QueryPackwerk
  # CLI for loading the QueryPackwerk console
  class CLI < Thor
    extend T::Sig

    # Thor maps --help to its help command only as the first argument, so commands check options[:help].
    class_option :help, type: :boolean, aliases: '-h', desc: 'Show this help message'
    check_unknown_options!

    default_command :console

    sig { returns(T::Boolean) }
    def self.exit_on_failure?
      true
    end

    desc 'console [DIRECTORY]', 'Query packwerk in DIRECTORY via console'
    long_desc 'Query packwerk in DIRECTORY via console. DIRECTORY defaults to the current directory.'
    sig { params(directory: String).void }
    def console(directory = Dir.pwd)
      return help('console') if options[:help]
      raise Thor::Error, "Could not find directory #{directory.inspect}." unless File.directory?(directory)

      QueryPackwerk::Console.start(directory)
    end
  end
end
