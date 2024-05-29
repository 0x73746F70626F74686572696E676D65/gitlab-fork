# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::CleanupWorker, feature_category: :subscription_management do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it { is_expected.to include_module(CronjobQueue) }
  it { expect(described_class.get_feature_category).to eq(:subscription_management) }

  describe '#perform' do
    let!(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        add_on: add_on,
        expires_on: expires_on.to_date,
        namespace: namespace
      )
    end

    let(:add_on) { create(:gitlab_subscription_add_on) }
    let(:namespace) { create(:group) }
    let(:expires_on) { 1.day.from_now }

    it_behaves_like 'an idempotent worker' do
      subject(:worker) { described_class.new }

      it 'does nothing' do
        worker.perform

        expect { add_on_purchase.reload }.not_to raise_error
      end

      context 'with expired add_on_purchase' do
        let(:expires_on) { (GitlabSubscriptions::AddOnPurchase::CLEANUP_DELAY_PERIOD + 1.day).ago }
        let(:expected_log) { { add_on: add_on.name, message: message, namespace: namespace.path } }
        let(:message) { 'Removable GitlabSubscriptions::AddOnPurchase was deleted via scheduled CronJob' }

        it 'destroys specific add-on purchase' do
          worker.perform

          expect { add_on_purchase.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'reduces amount of stored add-on purchases' do
          expect { worker.perform }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(-1)
        end

        it 'logs the deletion' do
          expect(Gitlab::AppLogger).to receive(:info).with(expected_log)

          worker.perform
        end

        context 'without namespace' do
          let(:namespace) { nil }
          let(:expected_log) { { add_on: add_on.name, message: message, namespace: nil } }

          it 'logs the deletion with blank namespace' do
            expect(Gitlab::AppLogger).to receive(:info).with(expected_log)

            worker.perform
          end
        end
      end
    end
  end
end
