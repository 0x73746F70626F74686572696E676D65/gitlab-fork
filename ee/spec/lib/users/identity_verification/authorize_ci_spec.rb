# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::IdentityVerification::AuthorizeCi, :saas, feature_category: :instance_resiliency do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }

  def stub_verifications(credit_card:, identity_verification:)
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:authorize_credit_card!) unless credit_card
      allow(instance).to receive(:authorize_identity_verification!) unless identity_verification
    end
  end

  describe '#authorize_run_jobs!' do
    subject(:authorize) { described_class.new(user: user, project: project).authorize_run_jobs! }

    shared_examples 'logs the failure and raises an exception' do
      before do
        allow(::Gitlab::AppLogger).to receive(:info)
      end

      specify :aggregate_failures do
        expect(::Gitlab::AppLogger)
          .to receive(:info)
          .with(
            message: error_message,
            class: described_class.name,
            project_path: project.full_path,
            user_id: user.id,
            plan: 'free')

        expect { authorize }.to raise_error(::Users::IdentityVerification::Error, error_message)
      end
    end

    shared_examples 'credit card verification' do
      let(:error_message) { 'Credit card required to be on file in order to run CI jobs' }

      context 'when the user has validated a credit card' do
        before do
          build(:credit_card_validation, user: user)
        end

        it { expect { authorize }.not_to raise_error }
      end

      context 'when the user has not validated a credit card' do
        before do
          allow(user).to receive(:has_required_credit_card_to_run_pipelines?).with(project).and_return(false)
        end

        it_behaves_like 'logs the failure and raises an exception'
      end
    end

    context 'when the user is nil' do
      let(:user) { nil }

      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:authorize_credit_card!).and_raise(::Users::IdentityVerification::Error)
          allow(instance).to receive(:authorize_identity_verification!).and_raise(::Users::IdentityVerification::Error)
        end
      end

      it { expect { authorize }.not_to raise_error }
    end

    context 'when shared runners are not enabled' do
      before do
        allow(project).to receive(:shared_runners_enabled).and_return(false)
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:authorize_credit_card!).and_raise(::Users::IdentityVerification::Error)
          allow(instance).to receive(:authorize_identity_verification!).and_raise(::Users::IdentityVerification::Error)
        end
      end

      it { expect { authorize }.not_to raise_error }
    end

    context 'when credit card verification is required' do
      before do
        stub_verifications(credit_card: true, identity_verification: false)
      end

      it_behaves_like 'credit card verification'
    end

    context 'when credit card and identity verification are required' do
      before do
        stub_verifications(credit_card: true, identity_verification: true)
      end

      it_behaves_like 'credit card verification'
    end

    context 'when identity verification is required' do
      before do
        stub_verifications(credit_card: false, identity_verification: true)
      end

      context 'when user identity is verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(true)
        end

        it { expect { authorize }.not_to raise_error }
      end

      context 'when user identity is not verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(false)
        end

        it_behaves_like 'logs the failure and raises an exception' do
          let(:error_message) { 'Identity verification is required in order to run CI jobs' }
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(ci_requires_identity_verification_on_free_plan: false)
          end

          it { expect { authorize }.not_to raise_error }
        end

        context 'when root namespace has a paid plan' do
          let_it_be(:ultimate_group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
          let_it_be(:project) { create(:project, group: ultimate_group) }

          it { expect { authorize }.not_to raise_error }
        end

        context 'when root namespace has purchased compute minutes' do
          before do
            project.namespace.update!(extra_shared_runners_minutes_limit: 100)
            project.namespace.clear_memoization(:ci_minutes_usage)
          end

          it { expect { authorize }.not_to raise_error }
        end
      end
    end
  end

  shared_examples 'verifying identity' do
    context 'when user identity is verified' do
      before do
        allow(user).to receive(:identity_verified?).and_return(true)
      end

      it { is_expected.to eq(true) }
    end

    context 'when user identity is not verified' do
      before do
        allow(user).to receive(:identity_verified?).and_return(false)
      end

      it { is_expected.to eq(false) }

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(ci_requires_identity_verification_on_free_plan: false)
        end

        it { is_expected.to eq(true) }
      end

      context 'when user identity is verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(true)
        end

        it { is_expected.to eq(true) }
      end

      context 'when root namespace has a paid plan' do
        let_it_be(:ultimate_group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
        let_it_be(:project) { create(:project, group: ultimate_group) }

        it { is_expected.to eq(true) }
      end

      context 'when root namespace has purchased compute minutes' do
        before do
          project.namespace.update!(extra_shared_runners_minutes_limit: 100)
          project.namespace.clear_memoization(:ci_minutes_usage)
        end

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '#user_can_run_jobs?' do
    subject { described_class.new(user: user, project: project).user_can_run_jobs? }

    context 'when project shared runners are disabled' do
      before do
        allow(project).to receive(:shared_runners_enabled).and_return(false)
      end

      it { is_expected.to eq(true) }
    end

    context 'when project shared runners enabled' do
      before do
        allow(project).to receive(:shared_runners_enabled).and_return(true)
      end

      it_behaves_like 'verifying identity'
    end
  end

  describe '#user_can_enable_shared_runners?' do
    subject { described_class.new(user: user, project: project).user_can_enable_shared_runners? }

    it_behaves_like 'verifying identity'
  end
end
