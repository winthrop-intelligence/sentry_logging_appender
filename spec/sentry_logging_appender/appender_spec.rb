# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

RSpec.describe SentryLoggingAppender::Appender do
  let(:sentry_logger) do
    # Accepts any method, any args, and keyword args for info/warn/error
    double('Logger').tap do |logger| # rubocop:disable RSpec/VerifiedDoubles
      %i[info warn error].each do |meth|
        allow(logger).to receive(meth).and_return(true)
      end
      allow(logger).to receive(:respond_to?).and_return(true)
    end
  end
  let(:log_struct) do
    # Split struct definition to avoid long lines
    Class.new(
      Struct.new(
        :name, :level, :level_index, :file_name_and_line, :message, :cleansed_message, :thread_name, :time,
        :duration, :duration_human, :metric, :metric_amount, :exception, :backtrace, :tags, :named_tags, :payload
      )
    ) do
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
    appender.log(log_event)
    expect(sentry_logger).to have_received(:info).with('Hello, Sentry!', hash_including(:origin, :logger))
  end

  it 'skips logging if Sentry is not initialized' do
    allow(Sentry).to receive(:initialized?).and_return(false)
    result = appender.log(log_event)
    expect(result).to be(false)
  end

  it "does not log Sentry's own messages" do
    log_event.name = 'Sentry'
    result = appender.log(log_event)
    expect(result).to be(false)
  end

  context 'when logging exceptions' do
    let(:exception) do
      e = StandardError.new('fail!')
      def e.backtrace = ['line 1', 'line 2']
      def e.level_index = 0
      e
    end

    before do
      log_event.exception = exception
      appender.log(log_event)
    end

    it 'includes exception class' do
      expect(sentry_logger).to have_received(:info).with(
        anything,
        hash_including(:exception_class)
      )
    end

    it 'includes exception message' do
      expect(sentry_logger).to have_received(:info).with(
        anything,
        hash_including(:exception_message)
      )
    end

    it 'includes exception backtrace' do
      expect(sentry_logger).to have_received(:info).with(
        anything,
        hash_including(:exception_backtrace)
      )
    end
  end

  context 'when logging backtrace without exception' do
    before do
      log_event.backtrace = %w[bt1 bt2]
      appender.log(log_event)
    end

    it 'includes backtrace' do
      expect(sentry_logger).to have_received(:info).with(
        anything,
        hash_including(:backtrace)
      )
    end
  end

  context 'when formatting user and tags attributes' do
    before do
      formatter = instance_double(SemanticLogger::Formatters::Raw)
      appender_with_formatter = described_class.new
      allow(formatter).to receive(:call).and_return(
        message: 'msg',
        level: :info,
        payload: {},
        named_tags: { user_id: 42, transaction_name: 'txn', foo: 'bar' },
        tags: %w[tag1 tag2]
      )
      allow(appender_with_formatter).to receive(:formatter).and_return(formatter)
      appender_with_formatter.log(log_event)
    end

    it 'includes user id' do
      expect(sentry_logger).to have_received(:info).with(
        'msg',
        hash_including(user: hash_including(id: 42))
      )
    end

    it 'includes tags' do
      expect(sentry_logger).to have_received(:info).with(
        'msg',
        hash_including(tags: hash_including('tag' => 'tag1, tag2'))
      )
    end
  end
end
