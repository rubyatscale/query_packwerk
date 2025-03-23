# typed: strict
# frozen_string_literal: true

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
          extend T::Sig

          sig { returns(String) }
          def inspect
            'query_packwerk console'
          end
        end

        irb = IRB::Irb.new(IRB::WorkSpace.new(context.new))
        IRB.conf[:MAIN_CONTEXT] = irb.context

        trap('SIGINT') do
          irb.signal_handle
        end

        puts 'QueryPackwerk Console'
        puts '====================='
        puts 'Available commands:'
        puts '  package(pack_name)                         - Get a package by name'
        puts '  Packages.all                               - Get all packages'
        puts ''
        puts 'Package Consumption (how others use this package):'
        puts '  violations_for(pack_name)                  - Get all violations where others access this package'
        puts '  violation_sources_for(pack_name)           - Get where others access this package'
        puts '  violation_counts_for(pack_name)            - Get how often others access this package'
        puts "  anonymous_violation_sources_for(pack_name) - Get the 'shape' of how others access this package"
        puts '  anonymous_violation_counts_for(pack_name)  - Get how often each access pattern occurs'
        puts '  consumers(pack_name)                       - Get which packages consume this package'
        puts ''
        puts 'Package Dependencies (how this package uses others):'
        puts '  todos_for(pack_name)                       - Get all todos where this package accesses others'
        puts ''
        puts 'Violations.all                               - Get all violations'
        puts ''

        catch(:IRB_EXIT) do
          irb.eval_input
        end
        Kernel.exit
      end
    end
  end
end
