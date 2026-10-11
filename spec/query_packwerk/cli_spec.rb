# typed: false
# frozen_string_literal: true

require 'tmpdir'
require 'query_packwerk/cli'

# An uncaught SystemExit aborts the rspec run; raise_error rescues it into a failure.
RSpec::Matchers.define_negated_matcher :not_raise_error, :raise_error

RSpec.describe QueryPackwerk::CLI do
  before do
    allow(QueryPackwerk::Console).to receive(:start)
  end

  describe 'console' do
    it 'is the default command' do
      described_class.start([])

      expect(QueryPackwerk::Console).to have_received(:start).with(Dir.pwd)
    end

    it 'starts the console in the current directory by default' do
      described_class.start(%w[console])

      expect(QueryPackwerk::Console).to have_received(:start).with(Dir.pwd)
    end

    it 'starts the console in the given directory' do
      Dir.mktmpdir do |directory|
        described_class.start(['console', directory])

        expect(QueryPackwerk::Console).to have_received(:start).with(directory)
      end
    end

    it 'exits with an error when the directory does not exist' do
      expect { described_class.start(%w[console does/not/exist]) }
        .to output(%(Could not find directory "does/not/exist".\n)).to_stderr
        .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

      expect(QueryPackwerk::Console).not_to have_received(:start)
    end

    it 'exits with an error when the path is a file' do
      Dir.mktmpdir do |directory|
        file = File.join(directory, 'package.yml')
        File.write(file, '')

        expect { described_class.start(['console', file]) }
          .to output(%(Could not find directory #{file.inspect}.\n)).to_stderr
          .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end

      expect(QueryPackwerk::Console).not_to have_received(:start)
    end

    it 'exits with an error when given an unknown option' do
      expect { described_class.start(%w[console --foo]) }
        .to output(/Unknown switches "--foo"/).to_stderr
        .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

      expect(QueryPackwerk::Console).not_to have_received(:start)
    end

    %w[--help -h].each do |flag|
      it "prints usage for #{flag} instead of starting the console" do
        # Thor wraps long_desc to the terminal width, hence \s+ between words.
        expect { described_class.start(['console', flag]) }
          .to output(/\AUsage:\n  \S+ console \[DIRECTORY\]\n.*DIRECTORY\s+defaults\s+to\s+the\s+current\s+directory/m).to_stdout
          .and not_raise_error

        expect(QueryPackwerk::Console).not_to have_received(:start)
      end
    end

    it 'prints usage for --help even when the directory does not exist' do
      expect { described_class.start(%w[console --help does/not/exist]) }
        .to output(/\AUsage:/).to_stdout
        .and not_raise_error

      expect(QueryPackwerk::Console).not_to have_received(:start)
    end
  end
end
