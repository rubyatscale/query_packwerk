# typed: false
# frozen_string_literal: true

require 'shellwords'

RSpec.describe QueryPackwerk::Pks do
  # A stand-in for pks that reports a version and prints references
  define_method(:write_pks) do |path, version: '0.7.0', version_output: "pks #{version}", references: [], warning: '', exit_status: 0|
    write_file(path, <<~SH)
      #!/bin/sh
      printf '%s' #{Shellwords.escape(warning)} >&2
      if [ "$1" = --version ]; then
        printf '%s\\n' #{Shellwords.escape(version_output)}
      else
        printf '%s\\n' #{Shellwords.escape(JSON.generate('references' => references))}
        exit #{exit_status}
      fi
    SH
    File.chmod(0o755, path)
  end

  define_method(:with_path) do |*directories, &block|
    original = ENV.fetch('PATH', nil)
    ENV['PATH'] = directories.map { |directory| File.expand_path(directory) }.join(File::PATH_SEPARATOR)
    block.call
  ensure
    ENV['PATH'] = original
  end

  let(:reference) do
    {
      'file' => 'packs/foo/app/services/foo.rb',
      'line' => 3,
      'column' => 4,
      'constant_name' => '::Bar',
      'referencing_pack_name' => 'packs/foo',
      'defining_pack_name' => 'packs/bar',
      'violations' => []
    }
  end

  describe '.list_references' do
    context 'with pks installed' do
      include_context 'referenced packs'

      it 'lists the references that the referenced packs context says it does' do
        begin
          described_class.executable
        rescue QueryPackwerk::Pks::Error => e
          skip e.message
        end

        expect(described_class.list_references).to eq(listed_references)
      end
    end

    it 'runs bin/pks, rather than pks on the PATH' do
      write_pks('bin/pks', references: [reference])
      write_pks('path/pks', references: [])

      with_path('path') do
        expect(described_class.list_references).to eq([reference])
      end
    end

    it 'runs pks on the PATH when there is no bin/pks' do
      write_pks('path/pks', references: [reference])

      with_path('empty', 'path') do
        expect(described_class.list_references).to eq([reference])
      end
    end

    it 'says to make bin/pks executable, rather than run pks on the PATH' do
      write_file('bin/pks', "#!/bin/sh\n")
      write_pks('path/pks', references: [reference])

      with_path('path') do
        expect { described_class.list_references }.to raise_error(
          QueryPackwerk::Pks::Error, "bin/pks isn't executable. To run it, `chmod +x bin/pks`"
        )
      end
    end

    it 'passes on what pks warns about' do
      write_pks('bin/pks', warning: "Couldn't parse packs/foo/app/models/foo.rb\n")

      expect { described_class.list_references }.to output("Couldn't parse packs/foo/app/models/foo.rb\n").to_stderr
    end

    it 'gets the version from what pks prints, rather than from what it warns about' do
      write_pks('bin/pks', references: [reference], warning: "warning: running pks from ~/.cargo/bin\n")

      expect { expect(described_class.list_references).to eq([reference]) }.to output.to_stderr
    end

    it 'reads what pks prints as UTF-8, whatever the locale' do
      reference['file'] = 'packs/foo/app/services/récolte.rb'
      write_pks('bin/pks', references: [reference])
      original = Encoding.default_external
      Encoding.default_external = Encoding::US_ASCII

      expect(described_class.list_references).to eq([reference])
    ensure
      Encoding.default_external = original
    end

    it 'says how to install pks when there is none' do
      with_path('empty') do
        expect { described_class.list_references }.to raise_error(
          QueryPackwerk::Pks::Error,
          "query_packwerk finds references with pks, which isn't in bin/pks or on your PATH. " \
          'To install it, see https://github.com/rubyatscale/pks/blob/main/INSTALLATION.md'
        )
      end
    end

    it 'says to upgrade a version of pks without list-references' do
      write_pks('bin/pks', version: '0.6.0')

      expect { described_class.list_references }.to raise_error(
        QueryPackwerk::Pks::Error,
        'query_packwerk finds references with `pks list-references`, which needs pks 0.7.0 or later, ' \
        "but #{File.expand_path('bin/pks')} is pks 0.6.0. " \
        'To upgrade it, see https://github.com/rubyatscale/pks/blob/main/INSTALLATION.md'
      )
    end

    it 'says when it cannot get the version of pks' do
      write_pks('bin/pks', version_output: "error: unexpected argument '--version'")

      expect { described_class.list_references }.to raise_error(
        QueryPackwerk::Pks::Error,
        "Could not get the version of #{File.expand_path('bin/pks')}:\nerror: unexpected argument '--version'\n"
      )
    end

    it 'checks the version each time it runs pks, as bin/pks can change with the branch' do
      write_pks('bin/pks')
      described_class.list_references
      write_pks('bin/pks', version: '0.6.0')

      expect { described_class.list_references }.to raise_error(QueryPackwerk::Pks::Error, /is pks 0\.6\.0\./)
    end

    it 'says what went wrong when pks fails' do
      write_pks('bin/pks', warning: "Error: No pack found 'packs/foo'", exit_status: 2)

      expect { described_class.list_references }.to raise_error(
        QueryPackwerk::Pks::Error,
        "`#{File.expand_path('bin/pks')} list-references` failed:\nError: No pack found 'packs/foo'"
      )
    end
  end
end
