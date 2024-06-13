# frozen_string_literal: true

module EE
  module Ci
    module RunnerPolicy
      extend ActiveSupport::Concern

      prepended do
        rule { auditor }.policy do
          enable :read_runner
          enable :read_builds
        end

        condition(:custom_role_enables_admin_runners) do
          ::Authz::CustomAbility.allowed?(@user, :admin_runners, @subject)
        end

        rule { custom_role_enables_admin_runners }.policy do
          enable :assign_runner
          enable :read_runner
          enable :update_runner
          enable :delete_runner
        end
      end
    end
  end
end
