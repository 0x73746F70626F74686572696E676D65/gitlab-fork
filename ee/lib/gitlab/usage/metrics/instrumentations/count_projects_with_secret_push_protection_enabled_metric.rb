# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class CountProjectsWithSecretPushProtectionEnabledMetric < DatabaseMetric
          operation :count

          relation do
            ProjectSecuritySetting.where(pre_receive_secret_detection_enabled: true)
          end
        end
      end
    end
  end
end
