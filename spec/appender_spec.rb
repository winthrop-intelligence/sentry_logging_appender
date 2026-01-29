# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

RSpec.describe SentryLoggingAppender::Appender do
  let(:sentry_logger) { double('SentryLogger') }
  let(:log_struct) do
    Class.new(Struct.new(
                :name, :level, :level_index, :file_name_and_line, :message, :cleansed_message, :thread_name, :time,
                :duration, :duration_human, :metric, :metric_amount, :exception, :backtrace, :tags, :named_tags, :payload
              )) do
      def each_exception
        yield exception if exception.respond_to?(:level_index) && exception.level_index && exception.level_index.zero?
      rescue NoMethodError
        # Ignore, for test safety
      end
    end
  end
  let(:log_event) do
    log_struct.new(
      'TestLogger', :info, 0, nil, 'Hello, Sentry!', 'Hello, Sentry!', 'main', Time.now,
      12.3, '12.3ms', nil, nil, nil, nil, [], {}, {}
    )
  end
  let(:appender) { described_class.new }

  before do
    stub_const('::Sentry', Module.new)
    allow(Sentry).to receive_messages(initialized?: true, logger: sentry_logger)
    allow(sentry_logger).to receive(:respond_to?).and_return(true)
    allow(sentry_logger).to receive(:info)
    allow(sentry_logger).to receive(:warn)
    allow(sentry_logger).to receive(:error)
  end

  it 'logs messages to Sentry when called' do
    expect(sentry_logger).to receive(:info).with('Hello, Sentry!', hash_including(:origin, :logger))
    appender.log(log_event)
  end

  it 'skips logging if Sentry is not initialized' do
    allow(Sentry).to receive(:initialized?).and_return(false)
    expect(sentry_logger).not_to receive(:info)
    expect(appender.log(log_event)).to be(false)
  end

  it "does not log Sentry's own messages" do
    log_event.name = 'Sentry'
    expect(sentry_logger).not_to receive(:info)
    expect(appender.log(log_event)).to be(false)
  end

  it 'logs exceptions as attributes' do
    exception = StandardError.new('fail!')
    def exception.backtrace
      ['line 1', 'line 2']
    end

    def exception.level_index
      0
    end
    log_event.exception = exception
    expect(sentry_logger).to receive(:info).with(
      anything,
      hash_including(:exception_class, :exception_message, :exception_backtrace)
    )
    appender.log(log_event)
  end

  it 'logs backtrace if present and no exception' do
    log_event.backtrace = %w[bt1 bt2]
    expect(sentry_logger).to receive(:info).with(
      anything,
      hash_including(:backtrace)
    )
    appender.log(log_event)
  end

  it 'formats user and tags attributes' do
    formatter = double('Formatter')
    allow(formatter).to receive(:call).and_return({
                                                    message: 'msg',
                                                    level: :info,
                                                    payload: {},
                                                    named_tags: { user_id: 42, transaction_name: 'txn', foo: 'bar' },
                                                    tags: %w[tag1 tag2]
                                                  })
    appender_with_formatter = described_class.new
    allow(appender_with_formatter).to receive(:formatter).and_return(formatter)
    expect(sentry_logger).to receive(:info).with(
      'msg',
      hash_including(user: hash_including(id: 42), tags: hash_including('tag' => 'tag1, tag2'))
    )
    appender_with_formatter.log(log_event)
  end
end
