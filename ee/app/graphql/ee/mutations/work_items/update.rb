# frozen_string_literal: true

module EE
  module Mutations
    module WorkItems
      module Update
        extend ActiveSupport::Concern

        prepended do
          argument :iteration_widget, ::Types::WorkItems::Widgets::IterationInputType,
            required: false,
            description: 'Input for iteration widget.'

          argument :weight_widget, ::Types::WorkItems::Widgets::WeightInputType,
            required: false,
            description: 'Input for weight widget.'

          argument :progress_widget, ::Types::WorkItems::Widgets::ProgressInputType,
            required: false,
            description: 'Input for progress widget.'

          argument :status_widget, ::Types::WorkItems::Widgets::StatusInputType,
            required: false,
            description: 'Input for status widget.'

          argument :health_status_widget, ::Types::WorkItems::Widgets::HealthStatusInputType,
            required: false,
            description: 'Input for health status widget.'

          argument :color_widget, ::Types::WorkItems::Widgets::ColorInputType,
            required: false,
            description: 'Input for color widget.'

          argument :rolledup_dates_widget, ::Types::WorkItems::Widgets::RolledupDatesInputType,
            required: false,
            description: 'Input for rolledup dates widget.',
            alpha: { milestone: '16.9' }
        end
      end
    end
  end
end
