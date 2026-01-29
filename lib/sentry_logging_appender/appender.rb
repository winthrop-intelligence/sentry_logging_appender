# frozen_string_literal: true

require 'semantic_logger'

# SentryLoggingAppender
#
# This module provides a Semantic Logger appender that sends logs to Sentry.
# It is designed to be used as a drop-in appender for Semantic Logger,
# formatting and forwarding log events to Sentry with user, tag, and context support.
module SentryLoggingAppender
  # Semantic Logger appender that sends logs to Sentry.
  class Appender < SemanticLogger::Subscriber # rubocop:disable Metrics/ClassLength
    # Create Appender
    #
    # Parameters are the same style as other SemanticLogger appenders:
    #   level:      minimum log level for this appender
    #   formatter:  object/proc/symbol for formatting, defaults to Raw
    #   filter:     regexp or proc to filter log events
    #   host:       host name to attach
    #   application: app name to attach
    #
    def initialize(level: :info, **args, &block)
      super
    end

    # Called by SemanticLogger for each log event
    def log(log) # rubocop:disable Naming/PredicateMethod
      return false unless loggable?(log)

      structured_logger = ::Sentry.logger
      context = formatter.call(log, self)
      attributes, message, level = build_sentry_attributes(log, context)
      send_to_sentry(structured_logger, level, message, attributes)
      true
    end

    private

    def send_to_sentry(structured_logger, level, message, attributes)
      level_method = sentry_level_method(structured_logger, level)
      structured_logger.public_send(level_method, message, **attributes)
    end

    def loggable?(log)
      return false if log.name == 'Sentry'

      return false unless defined?(::Sentry)

      return false unless ::Sentry.initialized?

      !::Sentry.logger.nil?
    end

    def build_sentry_attributes(log, context)
      payload = extract_payload!(context)
      named_tags = extract_named_tags!(context)
      transaction_name = extract_transaction_name!(named_tags)
      user = extract_user_from_sources(named_tags, payload)
      tags = extract_tags!(context)
      level = extract_level(context, log)
      message = extract_message(context, log)
      attributes = build_full_attributes(log, transaction_name, user, tags, context, payload)
      [attributes, message, level]
    end

    def extract_payload!(context)
      context.delete(:payload) || {}
    end

    def extract_named_tags!(context)
      context[:named_tags] || {}
    end

    def extract_transaction_name!(named_tags)
      named_tags.delete(:transaction_name)
    end

    # rubocop:disable Metrics/ParameterLists
    def build_full_attributes(log, transaction_name, user, tags, context, payload)
      # rubocop:enable Metrics/ParameterLists

      attributes = base_sentry_attributes(log, transaction_name)
      add_user_and_tags!(attributes, user, tags)
      merge_context_and_payload!(attributes, context, payload)
      add_exception_or_backtrace!(attributes, log)
      attributes
    end

    def extract_level(context, log)
      (context.delete(:level) || log.level).to_sym
    end

    def extract_message(context, log)
      context.delete(:message) || log.message
    end

    def merge_context_and_payload!(attributes, context, payload)
      attributes.merge!(context)
      attributes.merge!(payload)
    end

    def base_sentry_attributes(log, transaction_name)
      base = base_sentry_core_attributes(log, transaction_name)
      add_optional_base_attributes!(base, log)
      base.compact
    end

    def base_sentry_core_attributes(log, transaction_name)
      {
        origin: 'semantic_logger',
        logger: log.name,
        application: application,
        environment: environment,
        host: host,
        thread: log.thread_name,
        transaction: transaction_name,
        time: log.time
      }
    end

    def add_optional_base_attributes!(base, log)
      base[:duration_ms] = log.duration if log.duration
      base[:metric] = log.metric if log.metric
      base[:metric_amount] = log.metric_amount if log.metric_amount
    end

    def add_user_and_tags!(attributes, user, tags)
      attributes[:user] = user if user
      attributes[:tags] = tags if tags && !tags.empty?
    end

    def add_exception_or_backtrace!(attributes, log)
      if log.exception
        attributes[:exception_class]     = log.exception.class.name
        attributes[:exception_message]   = log.exception.message
        attributes[:exception_backtrace] = log.exception.backtrace
      elsif log.backtrace
        attributes[:backtrace] = log.backtrace
      end
    end

    def sentry_level_method(structured_logger, level)
      if structured_logger.respond_to?(level)
        level
      elsif %i[warn warning].include?(level) && structured_logger.respond_to?(:warn)
        :warn
      else
        :info
      end
    end

    def default_formatter
      SemanticLogger::Formatters::Raw.new
    end

    def extract_user_from_sources(*sources)
      user = extract_user_keys_from_sources(*sources)
      return if user.empty?

      sources.each { |source| merge_user_extras!(user, source) }
      user
    end

    def extract_user_keys_from_sources(*sources)
      keys = {
        user_id: :id,
        username: :username,
        user_email: :email,
        ip_address: :ip_address
      }
      user = {}
      sources.each { |source| extract_user_keys!(user, source, keys) }
      user
    end

    def extract_user_keys!(user, source, keys)
      keys.each do |source_key, target_key|
        value = source.delete(source_key)
        user[target_key] = value if value
      end
    end

    def merge_user_extras!(user, source)
      extras = source.delete(:user)
      user.merge!(extras) if extras.is_a?(Hash)
    end

    def extract_tags!(context)
      named_tags = (context.delete(:named_tags) || {}).transform_keys(&:to_s).transform_values(&:to_s)
      tags = context.delete(:tags)
      if tags
        tags_value = tags.join(', ')
        named_tags['tag'] = [named_tags['tag'], tags_value].compact.join(', ')
      end
      named_tags.transform_keys { |k| k[0...32] }
                .transform_values { |v| v[0...256] }
    end
  end
end
