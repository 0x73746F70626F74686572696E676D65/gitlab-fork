# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::Status, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:member) { create(:group_member) }
  let_it_be(:user) { member.user }

  describe '.enabled?' do
    subject { described_class.enabled? }

    context 'when on SaaS', :saas do
      it { is_expected.to eq(true) }
    end

    context 'when not on SaaS' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#continue_full_onboarding?' do
    let(:instance) { described_class.new(nil, nil, nil) }

    subject { instance.continue_full_onboarding? }

    where(
      subscription?: [true, false],
      invite?: [true, false],
      oauth?: [true, false],
      enabled?: [true, false]
    )

    with_them do
      let(:expected_result) { !subscription? && !invite? && !oauth? && enabled? }

      before do
        allow(instance).to receive(:subscription?).and_return(subscription?)
        allow(instance).to receive(:invite?).and_return(invite?)
        allow(instance).to receive(:oauth?).and_return(oauth?)
        allow(instance).to receive(:enabled?).and_return(enabled?)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#registration_type' do
    where(:registration_type, :expected_klass) do
      'free'         | ::Onboarding::FreeRegistration
      'trial'        | ::Onboarding::TrialRegistration
      'invite'       | ::Onboarding::InviteRegistration
      'subscription' | ::Onboarding::SubscriptionRegistration
      nil            | ::Onboarding::FreeRegistration
    end

    with_them do
      let(:current_user) { build(:user, onboarding_status_registration_type: registration_type) }

      specify do
        expect(described_class.new({}, nil, current_user).registration_type).to eq expected_klass
      end
    end
  end

  describe '#redirect_to_company_form?' do
    where(:registration_type, :expected_result) do
      'free'         | false
      'trial'        | true
      'invite'       | false
      'subscription' | false
      nil            | false
    end

    with_them do
      let(:current_user) { build(:user, onboarding_status_registration_type: registration_type) }
      let(:instance) { described_class.new({}, nil, current_user) }

      subject { instance.redirect_to_company_form? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#convert_to_automatic_trial?' do
    where(:setup_for_company?, :invite?, :subscription?, :trial?, :expected_result) do
      true  | false | false | false | true
      false | false | false | false | false
      false | true  | false | false | false
      true  | true  | false | false | false
      true  | false | true  | false | false
      true  | false | false | true  | false
    end

    with_them do
      let(:instance) { described_class.new({}, nil, nil) }

      subject { instance.convert_to_automatic_trial? }

      before do
        allow(instance).to receive(:invite?).and_return(invite?)
        allow(instance).to receive(:subscription?).and_return(subscription?)
        allow(instance).to receive(:trial?).and_return(trial?)
        allow(instance).to receive(:setup_for_company?).and_return(setup_for_company?)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#setup_for_company?' do
    where(:params, :expected_result) do
      { user: { setup_for_company: true } }  | true
      { user: { setup_for_company: false } } | false
      { user: {} }                           | false
    end

    with_them do
      let(:instance) { described_class.new(params, nil, nil) }

      subject { instance.setup_for_company? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#invite?' do
    let(:user_with_invite_registration_type) { build_stubbed(:user, onboarding_status_registration_type: 'invite') }
    let(:user_without_invite_registration_type) { build_stubbed(:user, onboarding_status_registration_type: 'free') }

    where(:current_user, :expected_result) do
      ref(:user_with_invite_registration_type)    | true
      ref(:user_without_invite_registration_type) | false
    end

    with_them do
      let(:instance) { described_class.new(nil, nil, current_user) }

      subject { instance.invite? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#joining_a_project?' do
    where(:params, :expected_result) do
      { joining_project: 'true' }  | true
      { joining_project: 'false' } | false
      {}                           | false
      { joining_project: '' }      | false
    end

    with_them do
      let(:instance) { described_class.new(params, nil, nil) }

      subject { instance.joining_a_project? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#tracking_label' do
    let(:instance) { described_class.new({}, nil, nil) }
    let(:trial?) { false }
    let(:invite?) { false }
    let(:subscription?) { false }

    subject(:tracking_label) { instance.tracking_label }

    before do
      allow(instance).to receive(:trial?).and_return(trial?)
      allow(instance).to receive(:invite?).and_return(invite?)
      allow(instance).to receive(:subscription?).and_return(subscription?)
    end

    it { is_expected.to eq('free_registration') }

    context 'when it is a trial' do
      let(:trial?) { true }

      it { is_expected.to eq('trial_registration') }
    end

    context 'when it is an invite' do
      let(:invite?) { true }

      it { is_expected.to eq('invite_registration') }
    end

    context 'when it is a subscription' do
      let(:subscription?) { true }

      it { is_expected.to eq('subscription_registration') }
    end
  end

  describe '#group_creation_tracking_label' do
    where(:trial?, :expected_result) do
      true  | 'trial_registration'
      false | 'free_registration'
    end

    with_them do
      let(:instance) { described_class.new({}, nil, nil) }

      subject { instance.group_creation_tracking_label }

      before do
        allow(instance).to receive(:trial?).and_return(trial?)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#trial?' do
    let(:user_with_trial) { build_stubbed(:user, onboarding_status_registration_type: 'trial') }

    where(:current_user, :onboarding_enabled?, :expected_result) do
      ref(:user)            | false | false
      ref(:user)            | true  | false
      ref(:user_with_trial) | true  | true
      ref(:user_with_trial) | false | false
    end

    with_them do
      let(:instance) { described_class.new(nil, nil, current_user) }

      subject { instance.trial? }

      before do
        stub_saas_features(onboarding: onboarding_enabled?)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#initial_trial?' do
    let(:user_with_initial_trial) { build_stubbed(:user, onboarding_status_initial_registration_type: 'trial') }
    let(:user_with_initial_free) { build_stubbed(:user, onboarding_status_initial_registration_type: 'free') }

    before do
      stub_saas_features(onboarding: true)
    end

    where(:current_user, :expected_result) do
      ref(:user)                    | false
      ref(:user_with_initial_trial) | true
      ref(:user_with_initial_free)  | false
    end

    with_them do
      let(:instance) { described_class.new(nil, nil, current_user) }

      subject { instance.initial_trial? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#oauth?' do
    let(:return_to) { nil }
    let(:session) { { 'user_return_to' => return_to } }

    subject { described_class.new(nil, session, nil).oauth? }

    context 'when in oauth' do
      let(:return_to) { ::Gitlab::Routing.url_helpers.oauth_authorization_path }

      it { is_expected.to eq(true) }

      context 'when there are params on the oauth path' do
        let(:return_to) { ::Gitlab::Routing.url_helpers.oauth_authorization_path(some_param: '_param_') }

        it { is_expected.to eq(true) }
      end
    end

    context 'when not in oauth' do
      context 'when no user location is stored' do
        it { is_expected.to eq(false) }
      end

      context 'when user location does not indicate oauth' do
        let(:return_to) { '/not/oauth/path' }

        it { is_expected.to eq(false) }
      end

      context 'when user location does not have value in session' do
        let(:session) { {} }

        it { is_expected.to eq(false) }
      end
    end
  end

  describe '#enabled?' do
    subject { described_class.new(nil, nil, nil).enabled? }

    context 'when on SaaS', :saas do
      it { is_expected.to eq(true) }
    end

    context 'when not on SaaS' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#subscription?' do
    let(:current_user) { build_stubbed(:user, onboarding_status_registration_type: 'subscription') }

    subject { described_class.new(nil, session, current_user).subscription? }

    context 'when onboarding feature is available' do
      before do
        stub_saas_features(onboarding: true)
      end

      it { is_expected.to eq(true) }

      context 'when the registration type is not subscription' do
        let(:current_user) { build_stubbed(:user, onboarding_status_registration_type: 'free') }

        it { is_expected.to eq(false) }
      end
    end

    context 'when onboarding feature is not available' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#iterable_product_interaction' do
    let(:current_user) { user }

    subject { described_class.new(nil, nil, current_user).iterable_product_interaction }

    context 'when invite registration is detected from onboarding_status' do
      context 'when it is an invite registration' do
        let(:current_user) { build_stubbed(:user, onboarding_status_registration_type: 'invite') }

        it { is_expected.to eq('Invited User') }
      end

      context 'when it is not an invite registration' do
        let(:current_user) { build_stubbed(:user, onboarding_status_registration_type: 'free') }

        it { is_expected.to eq('Personal SaaS Registration') }
      end
    end
  end

  describe '#company_lead_product_interaction' do
    before do
      stub_saas_features(onboarding: true)
    end

    subject { described_class.new(nil, nil, user).company_lead_product_interaction }

    context 'when it is a true trial registration' do
      let(:user) do
        build_stubbed(
          :user, onboarding_status_initial_registration_type: 'trial', onboarding_status_registration_type: 'trial'
        )
      end

      it { is_expected.to eq('SaaS Trial') }
    end

    context 'when it is an automatic trial registration' do
      it { is_expected.to eq('SaaS Trial - defaulted') }
    end

    context 'when it is initially free registration_type' do
      let(:current_user) { build_stubbed(:user) { |u| u.onboarding_status_initial_registration_type = 'free' } }

      context 'when it has trial set from params' do
        it { is_expected.to eq('SaaS Trial - defaulted') }
      end

      context 'when it does not have trial set from params' do
        let(:params) { {} }

        it { is_expected.to eq('SaaS Trial - defaulted') }
      end

      context 'when it is now a trial registration_type' do
        let(:params) { {} }

        before do
          current_user.onboarding_status_registration_type = 'trial'
        end

        it { is_expected.to eq('SaaS Trial - defaulted') }
      end
    end
  end

  describe '#preregistration_tracking_label' do
    let(:params) { {} }
    let(:session) { {} }
    let(:instance) { described_class.new(params, session, nil) }

    subject(:preregistration_tracking_label) { instance.preregistration_tracking_label }

    it { is_expected.to eq('free_registration') }

    context 'when it is an invite' do
      let(:params) { { invite_email: 'some_email@example.com' } }

      it { is_expected.to eq('invite_registration') }
    end

    context 'when it is a subscription' do
      let(:session) { { 'user_return_to' => ::Gitlab::Routing.url_helpers.new_subscriptions_path } }

      it { is_expected.to eq('subscription_registration') }
    end
  end

  describe '#eligible_for_iterable_trigger?' do
    let(:params) { {} }
    let(:current_user) { nil }
    let(:instance) { described_class.new(params, nil, current_user) }

    subject { instance.eligible_for_iterable_trigger? }

    where(
      trial?: [true, false],
      invite?: [true, false],
      redirect_to_company_form?: [true, false],
      continue_full_onboarding?: [true, false]
    )

    with_them do
      let(:expected_result) do
        (!trial? && invite?) || (!trial? && !redirect_to_company_form? && continue_full_onboarding?)
      end

      before do
        allow(instance).to receive(:trial?).and_return(trial?)
        allow(instance).to receive(:invite?).and_return(invite?)
        allow(instance).to receive(:redirect_to_company_form?).and_return(redirect_to_company_form?)
        allow(instance).to receive(:continue_full_onboarding?).and_return(continue_full_onboarding?)
      end

      it { is_expected.to eq(expected_result) }
    end

    context 'when setup_for_company is true and a user registration is an invite' do
      let(:params) { { user: { setup_for_company: true } } }
      let(:current_user) { build_stubbed(:user, onboarding_status_registration_type: 'invite') }

      it { is_expected.to eq(true) }
    end
  end

  describe '#stored_user_location' do
    let(:return_to) { nil }
    let(:session) { { 'user_return_to' => return_to } }

    subject { described_class.new(nil, session, nil).stored_user_location }

    context 'when no user location is stored' do
      it { is_expected.to be_nil }
    end

    context 'when user location exists' do
      let(:return_to) { '/some/path' }

      it { is_expected.to eq(return_to) }
    end

    context 'when user location does not have value in session' do
      let(:session) { {} }

      it { is_expected.to be_nil }
    end
  end
end
