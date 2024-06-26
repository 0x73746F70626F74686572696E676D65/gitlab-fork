# frozen_string_literal: true

module EE
  module Gitlab
    module SidekiqMiddleware
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :server_configurator
        def server_configurator(metrics: true, arguments_logger: true, skip_jobs: true)
          ->(chain) do
            super.call(chain)
            chain.add ::Gitlab::SidekiqMiddleware::SetSession::Server
          end
        end

        override :client_configurator
        def client_configurator
          ->(chain) do
            super.call(chain)
          end
        end
      end
    end
  end
end
