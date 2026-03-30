# Repository Guidelines

## Project Structure & Module Organization
This repository is a small Ruby gem that exposes a Semantic Logger appender for Sentry. Runtime code lives under `lib/`: the gem entrypoint is `lib/sentry_logging_appender.rb`, versioning is in `lib/sentry_logging_appender/version.rb`, and the main implementation is `lib/sentry_logging_appender/appender.rb`. Tests live under `spec/`, with support in `spec/spec_helper.rb` and feature-level specs mirroring the library path, for example `spec/sentry_logging_appender/appender_spec.rb`.

## Build, Test, and Development Commands
Install dependencies with `bundle install`. Run the full test suite with `bundle exec rspec`. Lint the codebase with `bundle exec rubocop`. Build the gem locally with `gem build sentry_logging_appender.gemspec`. When validating a change, prefer running lint and tests before opening a PR.

## Coding Style & Naming Conventions
Target Ruby 3.0 and follow the existing two-space indentation style. Keep files `# frozen_string_literal: true` at the top, match module and class names to the gem namespace (`SentryLoggingAppender::Appender`), and use snake_case for file names and method names. RuboCop with `rubocop-rspec` is the enforced style baseline; if you add exceptions, keep them narrow and inline.

## Testing Guidelines
RSpec is the test framework. Add specs beside the behavior they cover and name files with the `_spec.rb` suffix. Prefer focused examples around logging behavior, Sentry payload shaping, and guard clauses such as uninitialized Sentry or self-logging prevention. Run `bundle exec rspec spec/sentry_logging_appender/appender_spec.rb` for fast iteration on the main appender.

## Commit & Pull Request Guidelines
Recent commits use short, imperative summaries such as `fix rubocop issues` and `add some basic tests`. Keep commit messages concise, lowercase is acceptable, and scope each commit to one logical change. Pull requests should describe the behavior change, list how it was verified (`bundle exec rspec`, `bundle exec rubocop`), and link any related issue. Include example log payloads or Sentry behavior notes when changing appender output.

## Configuration Notes
The gem depends on `semantic_logger` and `sentry-ruby`, and runtime behavior assumes `Sentry` is initialized by the host application. Do not hardcode DSNs or credentials in tests or docs; use environment-driven configuration such as `SENTRY_DSN`.
