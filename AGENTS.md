This file provides guidance to AI coding agents when working with code in this repository.

## What this project is

`danger-packwerk` is a [Danger](https://danger.systems/ruby/) plugin that integrates packwerk into pull request workflows. It runs `packwerk check` and posts inline PR comments for any new boundary violations introduced by a diff.

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

- `lib/danger_packwerk.rb` — Danger plugin entry point; defines the `packwerk` Danger DSL method
- `lib/danger_packwerk/` — core logic: runs packwerk, diffs violations against the base branch, formats inline GitHub review comments
- `spec/` — RSpec tests
