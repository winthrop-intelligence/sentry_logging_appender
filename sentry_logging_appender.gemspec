Gem::Specification.new do |spec|
  spec.name          = "sentry_logging_appender"
  spec.version       = SentryLoggingAppender::VERSION
  spec.authors       = ["Eric Hedberg"]
  spec.email         = ["eric@winthropintelligence.com"]

  spec.summary       = "Semantic Logger appender for Sentry."
  spec.description   = "A Semantic Logger appender that sends logs directly to Sentry."
  spec.homepage      = "https://github.com/winthropintelligence/sentry_logging_appender"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "semantic_logger"
  spec.add_dependency "sentry-ruby"
end
