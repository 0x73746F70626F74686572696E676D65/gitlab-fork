# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        class Sequence
          def initialize(pipeline, command, sequence)
            @pipeline = pipeline
            @command = command
            @sequence = sequence
            @start = Time.now
          end

          def build!
            @sequence.each do |step_class|
              step_start = ::Gitlab::Metrics::System.monotonic_time
              step = step_class.new(@pipeline, @command)

              step.perform!

              @command.observe_step_duration(
                step_class,
                ::Gitlab::Metrics::System.monotonic_time - step_start
              )

              break if step.break?
            end

            @command.observe_creation_duration(Time.now - @start)
            @command.observe_pipeline_size(@pipeline)
            @command.observe_jobs_count_in_alive_pipelines

            @pipeline
          end
        end
      end
    end
  end
end
