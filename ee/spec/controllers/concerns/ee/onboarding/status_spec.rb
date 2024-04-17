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

  describe '#redirect_to_company_form?' do
    where(:converted_to_automatic_trial?, :trial?, :expected_result) do
      true  | false | true
      false | false | false
      false | true  | true
    end

    with_them do
      let(:instance) { described_class.new({}, nil, nil) }

      subject { instance.redirect_to_company_form? }

      before do
        allow(instance).to receive(:trial?).and_return(trial?)
        allow(instance).to receive(:converted_to_automatic_trial?).and_return(converted_to_automatic_trial?)
      end

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
    let(:user_without_members) { build_stubbed(:user) }
    let(:user_with_invite_registration_type) do
      user_without_members.onboarding_status_registration_type = 'invite'
      user_without_members
    end

    let(:user_without_invite_registration_type) do
      user_without_members.onboarding_status_registration_type = 'free'
      user_without_members
    end

    where(:current_user, :expected_result) do
      ref(:user)                                  | true
      ref(:user_without_members)                  | false
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

  describe '#trial_onboarding_flow?' do
    where(:params, :expected_result) do
      { trial_onboarding_flow: 'true' }  | true
      { trial_onboarding_flow: 'false' } | false
      {}                                 | false
      { trial_onboarding_flow: '' }      | false
    end

    with_them do
      let(:instance) { described_class.new(params, nil, nil) }

      subject { instance.trial_onboarding_flow? }

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

  describe '#onboarding_tracking_label' do
    let(:instance) { described_class.new({}, nil, nil) }
    let(:trial_onboarding_flow?) { false }

    subject(:tracking_label) { instance.onboarding_tracking_label }

    before do
      allow(instance).to receive(:trial_onboarding_flow?).and_return(trial_onboarding_flow?)
    end

    it { is_expected.to eq('free_registration') }

    context 'when it is a trial_onboarding_flow' do
      let(:trial_onboarding_flow?) { true }

      it { is_expected.to eq('trial_registration') }
    end
  end

  describe '#group_creation_tracking_label' do
    where(:trial_onboarding_flow?, :trial?, :expected_result) do
      true  | true  | 'trial_registration'
      true  | false | 'trial_registration'
      false | true  | 'trial_registration'
      false | false | 'free_registration'
    end

    with_them do
      let(:instance) { described_class.new({}, nil, nil) }

      subject { instance.group_creation_tracking_label }

      before do
        allow(instance).to receive(:trial_onboarding_flow?).and_return(trial_onboarding_flow?)
        allow(instance).to receive(:trial?).and_return(trial?)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#trial?' do
    let(:user_on_trial) { { 'user_return_to' => 'some/path?trial=true' } }
    let(:user_not_on_trial) { { 'user_return_to' => 'some/path?trial=false' } }
    let(:redirect_on_trial) { { 'redirect_return_to' => 'some/path?trial=true' } }
    let(:redirect_not_on_trial) { { 'redirect_return_to' => 'some/path?trial=false' } }
    let(:combined_not_on_trial) do
      { 'redirect_return_to' => 'some/path?trial=false', 'user_return_to' => 'some/path?trial=true' }
    end

    let(:combined_on_trial) do
      { 'redirect_return_to' => 'some/path?trial=true', 'user_return_to' => 'some/path?trial=false' }
    end

    let(:user_with_trial) { build_stubbed(:user) { |u| u.onboarding_status_registration_type = 'trial' } }

    where(:params, :current_user, :session, :onboarding_enabled?, :expected_result) do
      { trial: 'true' }  | ref(:user)            | {}                          | false | false
      { trial: 'false' } | ref(:user_with_trial) | {}                          | true  | true
      { trial: 'false' } | ref(:user)            | {}                          | true  | false
      { trial: 'true' }  | ref(:user)            | {}                          | true  | true
      { trial: 'false' } | ref(:user)            | ref(:user_on_trial)         | false | false
      { trial: 'false' } | ref(:user)            | ref(:user_on_trial)         | true  | true
      { trial: 'true' }  | ref(:user)            | ref(:user_on_trial)         | true  | true
      { trial: 'false' } | ref(:user)            | ref(:redirect_on_trial)     | false | false
      { trial: 'false' } | ref(:user)            | ref(:redirect_on_trial)     | true  | true
      { trial: 'true' }  | ref(:user)            | ref(:redirect_on_trial)     | true  | true
      { trial: 'false' } | ref(:user)            | ref(:user_not_on_trial)     | true  | false
      { trial: 'false' } | ref(:user)            | ref(:redirect_not_on_trial) | true  | false
      { trial: 'false' } | ref(:user)            | ref(:combined_on_trial)     | true  | true
      {}                 | ref(:user)            | {}                          | true  | false
      {}                 | ref(:user)            | {}                          | false | false
      { trial: '' }      | ref(:user)            | {}                          | false | false
      { trial: '' }      | ref(:user)            | {}                          | true  | false
      { trial: '' }      | ref(:user)            | nil                         | true  | false
    end

    with_them do
      let(:instance) { described_class.new(params, session, current_user) }

      subject { instance.trial? }

      before do
        stub_saas_features(onboarding: onboarding_enabled?)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#trial_from_the_beginning?' do
    let(:user_with_initial_trial) do
      build_stubbed(:user) { |u| u.onboarding_status_initial_registration_type = 'trial' }
    end

    let(:user_with_initial_free) { build_stubbed(:user) { |u| u.onboarding_status_initial_registration_type = 'free' } }

    before do
      stub_saas_features(onboarding: true)
    end

    where(:params, :current_user, :expected_result) do
      { trial: 'true' }  | ref(:user)                    | true
      { trial: 'false' } | ref(:user)                    | false
      { trial: 'false' } | ref(:user_with_initial_trial) | true
      { trial: 'false' } | ref(:user_with_initial_free)  | false
    end

    with_them do
      let(:instance) { described_class.new(params, nil, current_user) }

      subject { instance.trial_from_the_beginning? }

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
    let(:return_to) { ::Gitlab::Routing.url_helpers.new_subscriptions_path }
    let(:session) { { 'user_return_to' => return_to } }
    let(:current_user) { user }

    subject { described_class.new(nil, session, current_user).subscription? }

    context 'when onboarding feature is available' do
      before do
        stub_saas_features(onboarding: true)
      end

      context 'when in subscription flow' do
        it { is_expected.to eq(true) }

        context 'when subscription is the registration_type in the database' do
          let(:return_to) { nil }
          let(:current_user) { build_stubbed(:user) { |u| u.onboarding_status_registration_type = 'subscription' } }

          it { is_expected.to eq(true) }
        end
      end

      context 'when not in subscription flow' do
        context 'when no user location is stored' do
          let(:return_to) { nil }

          it { is_expected.to eq(false) }
        end

        context 'when user location does not indicate subscription' do
          let(:return_to) { '/not/subscription/path' }

          it { is_expected.to eq(false) }
        end

        context 'when user location does not have value in session' do
          let(:session) { {} }

          it { is_expected.to eq(false) }
        end

        context 'when the registration type is not subscription' do
          let(:return_to) { nil }
          let(:current_user) { build_stubbed(:user) { |u| u.onboarding_status_registration_type = 'free' } }

          it { is_expected.to eq(false) }
        end
      end
    end

    context 'when onboarding feature is not available' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#iterable_product_interaction' do
    let(:current_user) { user }

    subject { described_class.new(nil, nil, current_user).iterable_product_interaction }

    context 'when invite registration is detected onboarding_status' do
      context 'when it is an invite registration' do
        let(:current_user) { build_stubbed(:user, onboarding_status_registration_type: 'invite') }

        it { is_expected.to eq('Invited User') }
      end

      context 'when it is not an invite registration' do
        let(:current_user) { build_stubbed(:user, onboarding_status_registration_type: 'free') }

        it { is_expected.to eq('Personal SaaS Registration') }
      end
    end

    context 'when invite registration is detected from user memberships' do
      context 'with members for the user' do
        it { is_expected.to eq('Invited User') }
      end

      context 'without members for the user' do
        let(:current_user) { build_stubbed(:user) }

        it { is_expected.to eq('Personal SaaS Registration') }
      end
    end
  end

  describe '#company_lead_product_interaction' do
    let(:params) { { trial: true } }
    let(:session) { { some_key: 'some_value' } }
    let(:current_user) { user }

    before do
      stub_saas_features(onboarding: true)
    end

    subject { described_class.new(params, session, current_user).company_lead_product_interaction }

    context 'with a trial registration' do
      it { is_expected.to eq('SaaS Trial') }
    end

    context 'with automatic trial' do
      let(:params) { { trial: false } }

      it { is_expected.to eq('SaaS Trial - defaulted') }
    end

    context 'when it has an initial trial registration_type' do
      let(:current_user) { build_stubbed(:user, onboarding_status_initial_registration_type: 'trial') }

      context 'when it has trial set from params' do
        it { is_expected.to eq('SaaS Trial') }
      end

      context 'when it is no longer a trial registration_type' do
        let(:params) { {} }

        it { is_expected.to eq('SaaS Trial - defaulted') }
      end

      context 'when it is still a trial registration_type' do
        let(:params) { {} }

        before do
          current_user.onboarding_status_registration_type = 'trial'
        end

        it { is_expected.to eq('SaaS Trial') }
      end
    end

    context 'when it is initially free registration_type' do
      let(:current_user) { build_stubbed(:user, onboarding_status_initial_registration_type: 'free') }

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

    context 'when setup_for_company is true and a user is a member already' do
      let(:params) { { user: { setup_for_company: true } } }
      let(:current_user) { user }

      it { is_expected.to eq(true) }
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
