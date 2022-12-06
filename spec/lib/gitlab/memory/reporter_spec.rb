# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Memory::Reporter, :aggregate_failures, feature_category: :application_performance do
  let(:fake_report) do
    Class.new do
      def name
        'fake_report'
      end

      def active?
        true
      end

      def run(writer)
        writer << 'I ran'
      end
    end
  end

  let(:logger) { instance_double(::Logger) }
  let(:report) { fake_report.new }

  after do
    FileUtils.rm_rf(reports_path)
  end

  describe '#run_report', time_travel_to: '2020-02-02 10:30:45 0000' do
    let(:report_duration_counter) { instance_double(::Prometheus::Client::Counter) }
    let(:file_size) { 1_000_000 }
    let(:report_file) { "#{reports_path}/fake_report.2020-02-02.10:30:45:000.worker_1.abc123.gz" }

    let(:input) { StringIO.new }
    let(:output) { StringIO.new }

    before do
      allow(SecureRandom).to receive(:uuid).and_return('abc123')

      allow(Gitlab::Metrics).to receive(:counter).and_return(report_duration_counter)
      allow(report_duration_counter).to receive(:increment)

      allow(::Prometheus::PidProvider).to receive(:worker_id).and_return('worker_1')
      allow(File).to receive(:size).with(report_file).and_return(file_size)

      allow(logger).to receive(:info)

      stub_gzip
    end

    shared_examples 'runs and stores reports' do
      it 'runs the given report and returns true' do
        expect(reporter.run_report(report)).to be(true)

        expect(output.string).to eq('I ran')
      end

      it 'closes read and write streams' do
        expect(input).to receive(:close).ordered.at_least(:once)
        expect(output).to receive(:close).ordered.at_least(:once)

        reporter.run_report(report)
      end

      it 'logs start and finish event' do
        expect(logger).to receive(:info).ordered.with(
          hash_including(
            message: 'started',
            pid: Process.pid,
            worker_id: 'worker_1',
            perf_report_worker_uuid: 'abc123',
            perf_report: 'fake_report'
          ))
        expect(logger).to receive(:info).ordered.with(
          hash_including(
            :duration_s,
            :cpu_s,
            perf_report_file: report_file,
            perf_report_size_bytes: file_size,
            message: 'finished',
            pid: Process.pid,
            worker_id: 'worker_1',
            perf_report_worker_uuid: 'abc123',
            perf_report: 'fake_report'
          ))

        reporter.run_report(report)
      end

      it 'increments Prometheus duration counter' do
        expect(report_duration_counter).to receive(:increment).with({ report: 'fake_report' }, an_instance_of(Float))

        reporter.run_report(report)
      end

      context 'when the report returns invalid file path' do
        before do
          allow(File).to receive(:size).with(report_file).and_raise(Errno::ENOENT)
        end

        it 'logs `0` as `perf_report_size_bytes`' do
          expect(logger).to receive(:info).ordered.with(
            hash_including(message: 'started')
          )
          expect(logger).to receive(:info).ordered.with(
            hash_including(message: 'finished', perf_report_size_bytes: 0)
          )

          reporter.run_report(report)
        end
      end

      context 'when an error occurs' do
        before do
          allow(report).to receive(:run).and_raise(RuntimeError.new('report failed'))
        end

        it 'logs the error and returns false' do
          expect(logger).to receive(:info).ordered.with(hash_including(message: 'started'))
          expect(logger).to receive(:error).ordered.with(
            hash_including(
              message: 'failed', error: '#<RuntimeError: report failed>'
            ))

          expect(reporter.run_report(report)).to be(false)
        end

        it 'closes read and write streams' do
          allow(logger).to receive(:info)
          allow(logger).to receive(:error)

          expect(input).to receive(:close).ordered.at_least(:once)
          expect(output).to receive(:close).ordered.at_least(:once)

          reporter.run_report(report)
        end

        context 'when compression process is still running' do
          it 'terminates the process' do
            allow(logger).to receive(:info)
            allow(logger).to receive(:error)

            expect(Gitlab::ProcessManagement).to receive(:signal).with(an_instance_of(Integer), :KILL)

            reporter.run_report(report)
          end
        end
      end

      context 'when a report is disabled' do
        it 'does nothing and returns false' do
          expect(report).to receive(:active?).and_return(false)
          expect(report).not_to receive(:run)
          expect(logger).not_to receive(:info)
          expect(report_duration_counter).not_to receive(:increment)

          reporter.run_report(report)
        end
      end
    end

    context 'when reports path is specified directly' do
      let(:reports_path) { Dir.mktmpdir }

      subject(:reporter) { described_class.new(reports_path: reports_path, logger: logger) }

      it_behaves_like 'runs and stores reports'
    end

    context 'when reports path is specified via environment' do
      let(:reports_path) { Dir.mktmpdir }

      subject(:reporter) { described_class.new(logger: logger) }

      before do
        stub_env('GITLAB_DIAGNOSTIC_REPORTS_PATH', reports_path)
      end

      it_behaves_like 'runs and stores reports'
    end

    context 'when reports path is not specified' do
      let(:reports_path) { reporter.reports_path }

      subject(:reporter) { described_class.new(logger: logger) }

      it 'defaults to a temporary location' do
        expect(reports_path).not_to be_empty
      end

      it_behaves_like 'runs and stores reports'
    end
  end

  # We need to stub out the call into gzip. We do this by intercepting the write
  # end of the pipe and replacing it with a StringIO instead, which we can
  # easily inspect for contents.
  def stub_gzip
    pid = 42
    allow(IO).to receive(:pipe).and_return([input, output])
    allow(Process).to receive(:spawn).with(
      "gzip", "--fast", in: input, out: an_instance_of(File), err: an_instance_of(IO)
    ).and_return(pid)
    allow(Process).to receive(:waitpid).with(pid)
  end
end
