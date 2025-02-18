# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CiMinutesUsageMailer do
  include EmailSpec::Matchers

  let(:namespace) { create(:group) }
  let(:recipients) { %w[bob@example.com john@example.com] }

  shared_examples 'mail format' do
    it { is_expected.to have_subject subject_text }
    it { is_expected.to bcc_to recipients }
    it { is_expected.to have_body_text group_path(namespace) }
    it { is_expected.to have_body_text body_text }
  end

  describe '#notify' do
    let(:subject_text) do
      "Action required: There are no remaining compute minutes for #{namespace.name}"
    end

    let(:body_text) { "has run out of Shared Runner compute minutes" }

    subject { described_class.notify(namespace, recipients) }

    context 'when it is a group' do
      it_behaves_like 'mail format'

      it { is_expected.to have_body_text buy_minutes_subscriptions_url(selected_group: namespace.id) }
    end

    context 'when it is a namespace' do
      it_behaves_like 'mail format' do
        let(:namespace) { create(:namespace) }

        it { is_expected.to have_body_text ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url }
      end
    end
  end

  describe '#notify_limit' do
    let(:percent) { 30 }
    let(:subject_text) do
      "Action required: Less than #{percent}% of compute minutes remain for #{namespace.name}"
    end

    let(:body_text) { "has #{percent}% or less Shared Runner compute minutes" }

    subject { described_class.notify_limit(namespace, recipients, percent) }

    context 'when it is a group' do
      it_behaves_like 'mail format'
    end

    context 'when it is a namespace' do
      it_behaves_like 'mail format' do
        let(:namespace) { create(:namespace) }

        it { is_expected.to have_body_text ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url }
      end
    end
  end
end
