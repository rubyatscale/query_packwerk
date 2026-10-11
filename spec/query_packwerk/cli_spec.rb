# typed: false
# frozen_string_literal: true

require 'tmpdir'
require 'query_packwerk/cli'

RSpec.describe QueryPackwerk::CLI do
  before do
    allow(QueryPackwerk::Console).to receive(:start)
  end

  describe 'console' do
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

    it 'exits with an error when given an unknown option' do
      expect { described_class.start(%w[console --foo]) }
        .to output(/Unknown switches "--foo"/).to_stderr
        .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

      expect(QueryPackwerk::Console).not_to have_received(:start)
    end

    %w[--help -h].each do |flag|
      it "prints usage for #{flag} instead of starting the console" do
        expect { described_class.start(['console', flag]) }
          .to output(/console \[DIRECTORY\].*Query packwerk in DIRECTORY via console \(defaults to the current directory\)/m).to_stdout

        expect(QueryPackwerk::Console).not_to have_received(:start)
      end
    end
  end
end
