# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::ExpiringWorker, type: :worker, feature_category: :system_access do
  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when a token is owned by a group bot', :freeze_time do
      let_it_be(:project_bot) { create(:user, :project_bot) }
      let_it_be(:group) { create(:group) }
      let_it_be(:expiring_token) { create(:personal_access_token, user: project_bot, expires_at: 5.days.from_now) }
      let_it_be(:group_hook) { create(:group_hook, group: group, resource_access_token_events: true) }
      let_it_be(:hook_data) { Gitlab::DataBuilder::ResourceAccessToken.build(expiring_token, :expiring, group) }
      let(:fake_wh_service) { double }

      before_all do
        group.add_developer(project_bot)
      end

      it 'executes access token webhook' do
        stub_licensed_features(group_webhooks: true)
        expect(Gitlab::DataBuilder::ResourceAccessToken).to receive(:build).and_return(hook_data)
        expect(fake_wh_service).to receive(:async_execute).once

        expect(WebHookService)
              .to receive(:new).with(group_hook, hook_data, 'resource_access_token_hooks') { fake_wh_service }

        worker.perform
      end
    end
  end
end
