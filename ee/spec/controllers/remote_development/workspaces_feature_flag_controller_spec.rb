# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::WorkspacesFeatureFlagController, feature_category: :remote_development do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, :nested) }
  let(:flag) { "the_flag" }
  let(:allowed_flag) { flag }

  describe "GET #show" do
    before do
      stub_const("#{described_class}::ALLOWED_FLAGS", [allowed_flag])
      sign_in(user)
    end

    context "when namespace is not found" do
      let(:non_existing_namespace_id) { -1 }
      let(:namespace_id) { non_existing_namespace_id }

      it "returns enabled as false" do
        get :show, params: { flag: flag, namespace_id: namespace_id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response["enabled"]).to eq false
      end
    end

    context "when namespace is found" do
      let(:namespace_id) { namespace.id }

      before do
        allow(Feature).to receive(:enabled?).and_call_original
        allow(Feature).to receive(:enabled?).with(flag.to_sym, namespace.root_ancestor).and_return(enabled)
      end

      context "when flag does not exist in the allow-list" do
        let(:enabled) { false }

        it "returns enabled as false" do
          get :show, params: { flag: "INVALID_FLAG", namespace_id: namespace_id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response["enabled"]).to eq enabled
        end
      end

      context "when flag exists in the allow-list but is not a known feature flag" do
        let(:enabled) { false }

        before do
          allow(Feature).to receive(:enabled?)
            .with(flag.to_sym, namespace.root_ancestor)
            .and_raise(Feature::InvalidFeatureFlagError)
        end

        it "returns enabled as false" do
          get :show, params: { flag: flag, namespace_id: namespace_id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response["enabled"]).to eq enabled
        end
      end

      context "when feature flag is enabled" do
        let(:enabled) { true }

        it "returns enabled as true" do
          get :show, params: { flag: flag, namespace_id: namespace_id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response["enabled"]).to eq enabled
        end

        context "when flag is not allowed" do
          let(:allowed_flag) { "a_different_flag" }

          it "returns enabled as false" do
            get :show, params: { flag: flag, namespace_id: namespace_id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["enabled"]).to eq false
          end
        end
      end

      context "when feature flag is disabled" do
        let(:enabled) { false }

        it "returns enabled as false" do
          get :show, params: { flag: flag, namespace_id: namespace_id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response["enabled"]).to eq enabled
        end
      end
    end
  end
end
