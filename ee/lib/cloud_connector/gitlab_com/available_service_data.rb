# frozen_string_literal: true

module CloudConnector
  module GitlabCom
    class AvailableServiceData < BaseAvailableServiceData
      extend ::Gitlab::Utils::Override

      attr_reader :backend

      def initialize(name, cut_off_date, bundled_with, backend)
        super(name, cut_off_date, bundled_with.keys)

        @bundled_with = bundled_with
        @backend = backend
      end

      override :access_token
      def access_token(resource = nil, extra_claims: {})
        ::Gitlab::CloudConnector::SelfIssuedToken.new(
          audience: backend,
          subject: Gitlab::CurrentSettings.uuid,
          scopes: scopes_for(resource),
          extra_claims: extra_claims
        ).encoded
      end

      private

      def scopes_for(resource)
        free_access? ? allowed_scopes_during_free_access : allowed_scopes_from_purchased_bundles_for(resource)
      end

      def allowed_scopes_from_purchased_bundles_for(resource)
        add_on_purchases_for(resource).uniq_add_on_names.flat_map do |name|
          @bundled_with[name]
        end.uniq
      end

      def allowed_scopes_during_free_access
        @bundled_with.values.flatten.uniq
      end
    end
  end
end
