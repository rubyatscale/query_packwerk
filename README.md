# QueryPackwerk

QueryPackwerk is a Ruby gem for querying and analyzing Packwerk violations in Ruby applications.
It provides a friendly API for exploring package.yml and package_todo.yml files, making it easier to manage module boundaries and dependencies in your codebase.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add query_packwerk
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install query_packwerk
```

## Usage

### Console Interface

The easiest way to use QueryPackwerk is through its interactive console:

```bash
query_packwerk console
```

This will load the Packwerk context from your current directory and provide you with an interactive Ruby console with QueryPackwerk methods available.

Available commands in the console:

```ruby
# Get all violations for a pack
violations_for("pack_name")

# Get where violations occurred
violation_sources_for("pack_name")

# Get how often violations occurred
violation_counts_for("pack_name")

# Get the 'shape' of violations
anonymous_violation_sources_for("pack_name")

# Get how often each shape occurs
anonymous_violation_counts_for("pack_name")

# Get who consumes this pack
consumers("pack_name")

# Get all packages
Packages.all

# Get all violations
Violations.all
```

### Ruby API

You can also use QueryPackwerk programmatically in your Ruby code:

```ruby
require 'query_packwerk'

# Get all violations for a pack
violations = QueryPackwerk.violations_for("my_pack")

# Get which files are consuming your pack and how many violations each has
consumers = QueryPackwerk.consumers("my_pack")

# Get a count of all violation types
counts = QueryPackwerk.violation_counts_for("my_pack")
```

## Examples

Analyze which parts of your codebase are most dependent on a package:

```ruby
# Find the top 5 consumers of your package
QueryPackwerk.consumers("my_pack").sort_by { |_, count| -count }.first(5)
```

Find the most common violation patterns:

```ruby
# Get anonymized violation patterns with a threshold of at least 3 occurrences
QueryPackwerk.anonymous_violation_counts_for("my_pack", threshold: 3)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/martinemde/query_packwerk.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
