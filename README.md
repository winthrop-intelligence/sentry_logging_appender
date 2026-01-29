# SentryLoggingAppender

A Semantic Logger appender that sends logs directly to Sentry.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sentry_logging_appender', git: 'https://github.com/your_org/sentry_logging_appender'
```

Or build and install locally:

```sh
gem build sentry_logging_appender.gemspec
gem install ./sentry_logging_appender-0.1.0.gem
```

## Usage


```ruby
# config/environments/production.rb
require 'sentry_logging_appender'

# Only add the Sentry appender if SENTRY_DSN is present
if ENV['SENTRY_DSN'].present?
	config.semantic_logger.add_appender(appender: SentryLoggingAppender::Appender.new)
end
```

This will forward all Semantic Logger events to Sentry in production when SENTRY_DSN is set.

## Development

After checking out the repo, run `bundle install` to install dependencies.

## License

MIT
