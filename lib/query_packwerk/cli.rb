# typed: strict

require "thor"

module QueryPackwerk
  # CLI for loading the QueryPackwerk console
  class CLI < Thor
    extend T::Sig

    default_command :console

    desc "console",
         "Query packwerk in the current directory via console"
    sig { params(directory: String).void }
    def console(directory = Dir.pwd)
      require "query_packwerk/console"
      QueryPackwerk::Console.start(directory)
    end
  end
end
