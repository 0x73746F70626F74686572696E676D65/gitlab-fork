# frozen_string_literal: true

module EE
  module Projects
    module JobsController
      extend ActiveSupport::Concern

      prepended do
        before_action only: [:show] do
          push_frontend_feature_flag(:root_cause_analysis_duo, @current_user)
        end
      end
    end
  end
end
