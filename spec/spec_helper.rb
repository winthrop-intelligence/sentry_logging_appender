# frozen_string_literal: true

require 'bundler/setup'
require 'sentry_logging_appender'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
