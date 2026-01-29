# frozen_string_literal: true

require 'semantic_logger'

module SentryLoggingAppender
  class Appender < SemanticLogger::Subscriber
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
    def log(log)
      return false if log.name == 'Sentry'
      return false unless defined?(::Sentry)
      return false unless ::Sentry.initialized?
      structured_logger = ::Sentry.logger
      return false unless structured_logger
      context = formatter.call(log, self)
      payload = context.delete(:payload) || {}
      named_tags       = context[:named_tags] || {}
      transaction_name = named_tags.delete(:transaction_name)
      user = extract_user!(named_tags, payload)
      tags = extract_tags!(context)
      level   = (context.delete(:level) || log.level).to_sym
      message = context.delete(:message) || log.message
      attributes = {
        origin: 'semantic_logger',
        logger: log.name,
        application: application,
        environment: environment,
        host: host,
        thread: log.thread_name,
        transaction: transaction_name,
        time: log.time,
        duration_ms: log.duration,
        metric: log.metric,
        metric_amount: log.metric_amount
      }.compact
      attributes[:user] = user if user
      attributes[:tags] = tags if tags && !tags.empty?
      attributes.merge!(context)
      attributes.merge!(payload)
      if log.exception
        attributes[:exception_class]     = log.exception.class.name
        attributes[:exception_message]   = log.exception.message
        attributes[:exception_backtrace] = log.exception.backtrace
      elsif log.backtrace
        attributes[:backtrace] = log.backtrace
      end
      level_method =
        if structured_logger.respond_to?(level)
          level
        elsif %i[warn warning].include?(level) && structured_logger.respond_to?(:warn)
          :warn
        else
          :info
        end
      structured_logger.public_send(level_method, message, **attributes)
      true
    end

    private

    def default_formatter
      SemanticLogger::Formatters::Raw.new
    end

    def extract_user!(*sources)
      keys = {
        user_id: :id,
        username: :username,
        user_email: :email,
        ip_address: :ip_address
      }
      user = {}
      sources.each do |source|
        keys.each do |source_key, target_key|
          value = source.delete(source_key)
          user[target_key] = value if value
        end
      end
      return if user.empty?
      sources.each do |source|
        extras = source.delete(:user)
        user.merge!(extras) if extras.is_a?(Hash)
      end
      user
    end

    def extract_tags!(context)
      named_tags = context.delete(:named_tags) || {}
      named_tags = named_tags.to_h { |k, v| [k.to_s, v.to_s] }
      tags = context.delete(:tags)
      if tags
        tags_value = tags.join(', ')
        named_tags['tag'] = if named_tags.key?('tag')
                              "#{named_tags['tag']}, #{tags_value}"
                            else
                              tags_value
                            end
      end
      named_tags.transform_keys { |k| k[0...32] }
                .transform_values { |v| v[0...256] }
    end
  end
end
