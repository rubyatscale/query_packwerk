# typed: false
# frozen_string_literal: true

require 'pry'
require 'query_packwerk'
require_relative 'support/pack_helpers'
require_relative 'support/pseudo_packs'
require 'rubocop/rspec/support'
require 'packs/rspec/support'
require 'packs-specification'

RSpec.configure do |config|
  config.include PackHelpers
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
