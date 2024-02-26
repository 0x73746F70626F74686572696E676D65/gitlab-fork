# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::CloudConnector, feature_category: :cloud_connector do
  subject(:helper) do
    Class.new do
      include API::Helpers::CloudConnector
    end.new
  end

  describe '#cloud_connector_headers' do
    context 'when the the user is present' do
      let(:user) { build(:user, id: 1) }

      it 'generates a hash with the required fields based on the user' do
        expect(helper.cloud_connector_headers(user)).to match(
          {
            'X-Gitlab-Instance-Id' => an_instance_of(String),
            'X-Gitlab-Global-User-Id' => an_instance_of(String),
            'X-Gitlab-Realm' => Gitlab::CloudConnector::GITLAB_REALM_SELF_MANAGED
          }
        )
      end
    end

    context 'when the the user argument is nil' do
      let(:user) { nil }

      it 'generates a hash without `X-Gitlab-Global-User-Id`' do
        expect(helper.cloud_connector_headers(user)).to match(
          {
            'X-Gitlab-Instance-Id' => an_instance_of(String),
            'X-Gitlab-Realm' => Gitlab::CloudConnector::GITLAB_REALM_SELF_MANAGED
          }
        )
      end
    end
  end
end
