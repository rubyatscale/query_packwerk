# QueryPackwerk

QueryPackwerk is a Ruby gem for querying and analyzing [Packwerk](https://github.com/Shopify/packwerk) violations in Ruby applications.
It provides a friendly API for exploring `package.yml` and `package_todo.yml` files, and the references between packs that [pks](https://github.com/rubyatscale/pks) lists, making it easier to manage module boundaries and dependencies in your codebase.

## Installation

This gem provides a CLI interface that can be used independently from your application.

```bash
gem install query_packwerk
```

You can also make it available in a specific application by adding it to your Gemfile:

```bash
bundle add query_packwerk --group=development
```

## Usage

### Console Interface

The easiest way to use QueryPackwerk is through its interactive console. This will use the local directory Packwerk context and provide you with all QueryPackwerk methods.

```bash
query_packwerk console
```

To use the Packwerk context of another directory, pass it as an argument:

```bash
query_packwerk console path/to/app
```

Run `query_packwerk console --help` for usage details.

The CLI includes a welcome message with a list of commands. You can access it any time with `welcome`:

```
query_packwerk:001:0> welcome
```

Find packages to work with:

```ruby
# Get a package
query_packwerk:001:0> package("pack_name")

# Get all packages
query_packwerk:001:0> Packages.all

# Find a package
query_packwerk:001:0> Packages.where(name: /service/)
```

Explore violations:

```ruby
# Get all violations for a pack
query_packwerk:001:0> violations_for("pack_name")

# Get where violations occurred
query_packwerk:001:0> violation_sources_for("pack_name")

# Get how often violations occurred
query_packwerk:001:0> violation_counts_for("pack_name")

# Get the 'shape' of violations
query_packwerk:001:0> anonymous_violation_sources_for("pack_name")

# Get how often each shape occurs
query_packwerk:001:0> anonymous_violation_counts_for("pack_name")

# Get who consumes this pack
query_packwerk:001:0> consumers("pack_name")

# Get all violations
query_packwerk:001:0> Violations.all

```

Explore references, whether or not they break a rule:

package_todo.yml files record only the references that break a pack's rules. To list every reference from one pack to another pack's constants, including those that a declared dependency or a public constant allows, QueryPackwerk runs [pks](https://github.com/rubyatscale/pks) 0.7.0 or later. It runs `bin/pks` if your app has one, or else `pks` on your `PATH`. See pks's [installation instructions](https://github.com/rubyatscale/pks/blob/main/INSTALLATION.md).

```ruby
# Get all references to a pack's constants
query_packwerk:001:0> references_for("pack_name")

# Get the 'shape' of the references to a pack that break no rule
query_packwerk:001:0> References.where(producing_pack: "packs/pack_name", allowed: true).anonymous_source_counts

# Get all references from a pack to other packs' constants
query_packwerk:001:0> references_from("pack_name")

# Get all references
query_packwerk:001:0> References.all
```

References have the same methods as violations, like `sources_with_locations` and `anonymous_source_counts`. Each one is where pks finds it, so its source is found even where the code names a constant relatively, as `Bar` inside `module Foo`. A reference that pks infers from an association, as `has_many :tacos` does for `Taco`, has the association as its source. pks gives no positions in ERB templates, so there a reference's sources are wherever the template names the constant. Finding sources parses each file they're in, which for a pack that thousands of files reference takes a while.

If you change any of the package.yml or package_todo.yml files, you can reload the running console:

```ruby
# Reset the cache, so the next query of references runs pks again
query_packwerk:001:0> reload!
```

### Ruby API

QueryPackwerk can also be used programmatically from Ruby:

```ruby
require 'query_packwerk'

# Get all violations for a pack
violations = QueryPackwerk.violations_for("my_pack")

# Get which files are consuming your pack and how many violations each has
consumers = QueryPackwerk.consumers("my_pack")

# Get a count of all violation types
counts = QueryPackwerk.violation_counts_for("my_pack")

# Get how other packs use your pack, whether or not they break a rule
QueryPackwerk.references_for("my_pack").anonymous_source_counts
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

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, bump `VERSION` in `lib/query_packwerk/version.rb` in your PR and run `bundle install` so `Gemfile.lock` matches. When the PR is merged and CI passes on `main`, the gem is tagged and published to RubyGems automatically. Merges that don't change the version don't publish anything.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubyatscale/query_packwerk.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
