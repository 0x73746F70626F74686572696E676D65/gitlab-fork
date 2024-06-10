# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::CodeSuggestionsController, :cloud_licenses, feature_category: :seat_cost_management do
  include AdminModeHelper

  describe 'GET /code_suggestions', :with_cloud_connector do
    let(:plan) { License::STARTER_PLAN }
    let(:license) { build(:license, plan: plan) }

    before do
      allow(License).to receive(:current).and_return(license)
      allow(::Gitlab::Saas).to receive(:feature_available?).and_return(false)
    end

    shared_examples 'renders the activation form' do
      it 'renders the activation form and skips completion test' do
        get admin_code_suggestions_path

        expect(response).to render_template(:index)
        expect(response.body).to include('js-code-suggestions-page')
        expect(flash.now[:notice]).to be_nil
        expect(flash.now[:alert]).to be_nil
      end

      context 'when duo pro addon is purchased' do
        let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :active) }

        context 'when connection check succeeds' do
          before do
            allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
              allow(client).to receive(:test_completion).and_return(nil)
            end
          end

          it 'renders the activation form' do
            get admin_code_suggestions_path

            expect(response).to render_template(:index)
            expect(response.body).to include('js-code-suggestions-page')
            expect(flash.now[:notice]).to eq("Code completion test was successful")
          end
        end

        context 'when connection check fails' do
          before do
            allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
              allow(client).to receive(:test_completion).and_return('an error')
            end
          end

          it 'renders the activation form with alert message' do
            get admin_code_suggestions_path

            expect(response).to render_template(:index)
            expect(response.body).to include('js-code-suggestions-page')
            expect(flash.now[:alert]).to eq("Code completion test failed: an error")
          end
        end
      end
    end

    shared_examples 'hides code suggestions path' do
      it 'returns 404' do
        get admin_code_suggestions_path

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response).to render_template('errors/not_found')
      end
    end

    context 'when the user is not admin' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it_behaves_like 'hides code suggestions path'
    end

    context 'when the user is an admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        login_as(admin)
        enable_admin_mode!(admin)
      end

      it_behaves_like 'renders the activation form'

      context 'when instance is self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        context 'when self_managed_code_suggestions feature flag is enabled' do
          before do
            stub_feature_flags(self_managed_code_suggestions: true)
          end

          it_behaves_like 'renders the activation form'
        end

        context 'when self_managed_code_suggestions feature flag is disabled' do
          before do
            stub_feature_flags(self_managed_code_suggestions: false)
          end

          it_behaves_like 'hides code suggestions path'
        end
      end

      context 'when instance is SaaS' do
        where(:self_managed_code_suggestions) do
          [true, false]
        end

        with_them do
          before do
            stub_saas_features(gitlab_com_subscriptions: true)
            stub_feature_flags(self_managed_code_suggestions: self_managed_code_suggestions)
          end

          it_behaves_like 'hides code suggestions path'
        end
      end

      context 'when the instance has a non-paid license' do
        let(:plan) { License::LEGACY_LICENSE_TYPE }

        it_behaves_like 'hides code suggestions path'
      end

      context 'when the instance does not have a license' do
        let(:license) { nil }

        it_behaves_like 'hides code suggestions path'
      end
    end
  end
end
