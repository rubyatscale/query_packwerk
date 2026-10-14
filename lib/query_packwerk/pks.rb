# typed: strict
# frozen_string_literal: true

require 'json'
require 'open3'

module QueryPackwerk
  # Runs pks (https://github.com/rubyatscale/pks), which lists every reference
  # from one pack to a constant that another pack defines, whether or not it
  # breaks the packs' rules. package_todo.yml files record only those that do.
  module Pks
    extend T::Sig

    class Error < StandardError; end

    # The first version with `list-references`
    MINIMUM_VERSION = Gem::Version.new('0.7.0')
    INSTALLATION_URL = 'https://github.com/rubyatscale/pks/blob/main/INSTALLATION.md'

    class << self
      extend T::Sig

      # The references in the app, as `pks list-references` prints them:
      # https://github.com/rubyatscale/pks/blob/main/schema/list-references-output.json
      sig { returns(T::Array[T::Hash[String, T.untyped]]) }
      def list_references
        pks = executable
        stdout, stderr, status = Open3.capture3(pks, 'list-references')
        raise Error, "`#{pks} list-references` failed:\n#{stderr}" unless status.success?

        # Warnings, as about a file that pks can't parse
        $stderr.print(stderr)
        JSON.parse(stdout).fetch('references')
      end

      # bin/pks, as in an app that pins a version of pks, or else pks on the PATH
      sig { returns(String) }
      def executable
        candidates = ['bin', *ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)].map do |directory|
          File.expand_path('pks', directory)
        end
        executable = candidates.find { |candidate| File.file?(candidate) && File.executable?(candidate) }
        unless executable
          raise Error, "query_packwerk finds references with pks, which isn't in bin/pks or on your PATH. " \
                       "To install it, see #{INSTALLATION_URL}"
        end

        check_version(executable)
        executable
      end

      private

      # Checked each time pks runs, since checking out another branch can change bin/pks
      sig { params(executable: String).void }
      def check_version(executable)
        output, status = Open3.capture2e(executable, '--version')
        version = output[/\Apks (\S+)/, 1]
        raise Error, "Could not get the version of #{executable}:\n#{output}" unless status.success? && version && Gem::Version.correct?(version)

        if Gem::Version.new(version) < MINIMUM_VERSION
          raise Error, "query_packwerk finds references with `pks list-references`, which needs pks #{MINIMUM_VERSION} " \
                       "or later, but #{executable} is pks #{version}. To upgrade it, see #{INSTALLATION_URL}"
        end
      end
    end
  end
end
