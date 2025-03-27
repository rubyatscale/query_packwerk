# typed: strict
# frozen_string_literal: true

require 'irb'
require 'irb/completion'

module QueryPackwerk
  # Console for QueryPackwerk
  class Console
    extend T::Sig

    sig { params(directory: String).void }
    def self.start(directory = Dir.pwd)
      puts "Loading packwerk context in #{directory}..."

      Dir.chdir(directory) do
        # Start IRB with current context
        # https://github.com/cucumber/aruba/blob/main/lib/aruba/console.rb
        ARGV.clear

        require 'irb'
        IRB.setup nil

        IRB.conf[:IRB_NAME] = 'query_packwerk'

        IRB.conf[:PROMPT] = {}
        IRB.conf[:PROMPT][:QUERY_PACKWERK] = {
          PROMPT_I: '%N:%03n:%i> ',
          PROMPT_S: '%N:%03n:%i%l ',
          PROMPT_C: '%N:%03n:%i* ',
          RETURN: "# => %s\n"
        }
        IRB.conf[:PROMPT_MODE] = :QUERY_PACKWERK

        IRB.conf[:RC] = false

        require 'irb/completion'
        IRB.conf[:READLINE] = true
        IRB.conf[:SAVE_HISTORY] = 1000
        IRB.conf[:HISTORY_FILE] = "#{directory}/.query_packwerk_history"

        context = Class.new do
          include QueryPackwerk
          include QueryPackwerk::ConsoleHelpers
          extend T::Sig
        end

        context_instance = context.new
        irb = IRB::Irb.new(IRB::WorkSpace.new(context_instance))
        IRB.conf[:MAIN_CONTEXT] = irb.context

        context_instance.welcome

        trap('SIGINT') do
          irb.signal_handle
        end

        catch(:IRB_EXIT) do
          irb.eval_input
        end
        Kernel.exit
      end
    end
  end
end
