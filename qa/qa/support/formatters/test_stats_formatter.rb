# frozen_string_literal: true

module QA
  module Support
    module Formatters
      class TestStatsFormatter < RSpec::Core::Formatters::BaseFormatter
        RSpec::Core::Formatters.register(self, :stop)

        # Finish test execution
        #
        # @param [RSpec::Core::Notifications::ExamplesNotification] notification
        # @return [void]
        def stop(notification)
          return log(:warn, 'Missing QA_INFLUXDB_URL, skipping metrics export!') unless influxdb_url
          return log(:warn, 'Missing QA_INFLUXDB_TOKEN, skipping metrics export!') unless influxdb_token

          data = notification.examples.map { |example| test_stats(example) }.compact
          influx_client.create_write_api.write(data: data)
          log(:info, "Pushed #{data.length} entries to influxdb")
        rescue StandardError => e
          log(:error, "Failed to push data to influxdb, error: #{e}")
        end

        private

        # InfluxDb client
        #
        # @return [InfluxDB2::Client]
        def influx_client
          @influx_client ||= InfluxDB2::Client.new(
            influxdb_url,
            influxdb_token,
            bucket: 'e2e-test-stats',
            org: 'gitlab-qa',
            use_ssl: false,
            precision: InfluxDB2::WritePrecision::NANOSECOND
          )
        end

        # InfluxDb instance url
        #
        # @return [String]
        def influxdb_url
          @influxdb_url ||= env('QA_INFLUXDB_URL')
        end

        # Influxdb token
        #
        # @return [String]
        def influxdb_token
          @influxdb_token ||= env('QA_INFLUXDB_TOKEN')
        end

        # Transform example to influxdb compatible metrics data
        # https://github.com/influxdata/influxdb-client-ruby#data-format
        #
        # @param [RSpec::Core::Example] example
        # @return [Hash]
        def test_stats(example)
          {
            name: 'test-stats',
            time: time,
            tags: {
              name: example.full_description,
              file_path: example.metadata[:file_path].gsub('./qa/specs/features', ''),
              status: example.execution_result.status,
              reliable: example.metadata.key?(:reliable).to_s,
              quarantined: example.metadata.key?(:quarantine).to_s,
              retried: ((example.metadata[:retry_attempts] || 0) > 0).to_s,
              job_name: job_name,
              merge_request: merge_request,
              run_type: env('QA_RUN_TYPE') || run_type
            },
            fields: {
              id: example.id,
              run_time: (example.execution_result.run_time * 1000).round,
              retry_attempts: example.metadata[:retry_attempts] || 0,
              job_url: QA::Runtime::Env.ci_job_url,
              pipeline_url: env('CI_PIPELINE_URL'),
              pipeline_id: env('CI_PIPELINE_ID')
            }
          }
        rescue StandardError => e
          log(:error, "Failed to transform example '#{example.id}', error: #{e}")
          nil
        end

        # Project name
        #
        # @return [String]
        def project_name
          @project_name ||= QA::Runtime::Env.ci_project_name
        end

        # Base ci job name
        #
        # @return [String]
        def job_name
          @job_name ||= QA::Runtime::Env.ci_job_name.gsub(%r{ \d{1,2}/\d{1,2}}, '')
        end

        # Single common timestamp for all exported example metrics to keep data points consistently grouped
        #
        # @return [Time]
        def time
          @time ||= DateTime.strptime(env('CI_PIPELINE_CREATED_AT')).to_time
        end

        # Is a merge request execution
        #
        # @return [String]
        def merge_request
          @merge_request ||= (!!env('CI_MERGE_REQUEST_IID') || !!env('TOP_UPSTREAM_MERGE_REQUEST_IID')).to_s
        end

        # Test run type from staging, canary or production env
        #
        # @return [String>, nil]
        def run_type
          return unless %w[staging canary production].include?(project_name)

          @run_type ||= begin
            test_subset = if env('NO_ADMIN') == 'true'
                            'sanity-no-admin'
                          elsif env('SMOKE_ONLY') == 'true'
                            'sanity'
                          else
                            'full'
                          end

            "#{project_name}-#{test_subset}"
          end
        end

        # Print log message
        #
        # @param [Symbol] level
        # @param [String] message
        # @return [void]
        def log(level, message)
          QA::Runtime::Logger.public_send(level, "influxdb exporter: #{message}")
        end

        # Return non empty environment variable value
        #
        # @param [String] name
        # @return [String, nil]
        def env(name)
          return unless ENV[name] && !ENV[name].empty?

          ENV[name]
        end
      end
    end
  end
end
