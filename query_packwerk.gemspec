# frozen_string_literal: true

require_relative 'lib/query_packwerk/version'

Gem::Specification.new do |spec|
  spec.name = 'query_packwerk'
  spec.version = QueryPackwerk::VERSION
  spec.authors = ['Gusto Engineering']
  spec.email = ['dev@gusto.com']

  spec.summary = 'Query Packwerk'
  spec.description = 'Query Packwerk violations and dependencies.'
  spec.homepage = 'https://github.com/gusto/query_packwerk'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/gusto/query_packwerk'
  spec.metadata['changelog_uri'] = 'https://github.com/gusto/query_packwerk/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ sorbet/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'coderay'
  spec.add_dependency 'packwerk'
  spec.add_dependency 'parse_packwerk'
  spec.add_dependency 'rubocop'
  spec.add_dependency 'sorbet-runtime'
  spec.add_dependency 'thor'
end
