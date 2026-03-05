This file provides guidance to AI coding agents when working with code in this repository.

## What this project is

`query_packwerk` is a Ruby gem for querying and analyzing [packwerk](https://github.com/Shopify/packwerk) violations and dependencies. It provides a fluent API and an interactive console for exploring `package.yml` and `package_todo.yml` files.

## Commands

```bash
bundle install

# Run all tests (RSpec)
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/path/to/spec.rb

# Lint
bundle exec rubocop
bundle exec rubocop -a  # auto-correct

# Type checking (Sorbet)
bundle exec srb tc
```

## Architecture

- `lib/query_packwerk.rb` — entry point and public API
- `lib/query_packwerk/` — query classes for violations, packages, and dependency graphs; also includes an interactive console (REPL) interface
- `spec/` — RSpec tests
