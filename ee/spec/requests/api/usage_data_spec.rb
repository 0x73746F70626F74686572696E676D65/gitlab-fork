# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::UsageData, feature_category: :service_ping do
  let_it_be(:user) { create(:user) }

  describe 'POST /usage_data/track_event' do
    let(:endpoint) { '/usage_data/track_event' }

    context 'with usage ping enabled' do
      before do
        stub_application_setting(usage_ping_enabled: true)
      end

      context 'with AI related metric' do
        let_it_be(:additional_properties) do
          {
            language: 'ruby',
            timestamp: DateTime.parse('2024-01-01')
          }
        end

        let(:event_name) { 'code_suggestions_shown' }

        it 'triggers AI tracking' do
          expect(Gitlab::Tracking::AiTracking).to receive(:track_event)
                                              .with(
                                                event_name,
                                                additional_properties.merge(user: user)
                                              ).and_call_original

          post api(endpoint, user), params: {
            event: event_name,
            additional_properties: additional_properties
          }

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'with transition approach' do
          before do
            allow(Gitlab::Tracking::AiTracking)
              .to receive(:track_via_code_suggestions?).with(event_name, anything).and_return(true)
          end

          it 'does not trigger AI tracking' do
            expect(Gitlab::Tracking::AiTracking).not_to receive(:track_event)

            post api(endpoint, user), params: {
              event: event_name,
              additional_properties: additional_properties
            }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end
  end
end
