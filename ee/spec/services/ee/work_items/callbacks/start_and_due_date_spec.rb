# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::StartAndDueDate, feature_category: :portfolio_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, reporter_of: project) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project) }

  let(:widget) { work_item.widgets.find { |widget| widget.is_a?(WorkItems::Callbacks::StartAndDueDate) } }

  describe '#before_update_callback' do
    let(:start_date) { Date.today }
    let(:due_date) { 1.week.from_now.to_date }
    let(:service) { described_class.new(issuable: work_item, current_user: user, params: params) }

    subject(:update_params) { service.before_update }

    shared_examples 'does not set synced_epic_params' do
      it 'does not set synced_epic_params' do
        update_params

        expect(service.synced_epic_params).to be_empty
      end
    end

    context 'when start and due date params are present' do
      let(:params) { { start_date: Date.today, due_date: 1.week.from_now.to_date } }

      it 'correctly sets synced_epic_params' do
        update_params

        expect(service.synced_epic_params[:start_date]).to eq(start_date)
        expect(service.synced_epic_params[:due_date]).to eq(due_date)
      end

      context "and user doesn't have permissions to update start and due date" do
        let_it_be(:user) { create(:user) }

        it_behaves_like 'does not set synced_epic_params'
      end
    end

    context 'when date params are not present' do
      let(:params) { {} }

      it_behaves_like 'does not set synced_epic_params'
    end

    context 'when start_date and due_date are null' do
      context 'when one of the two params is null' do
        let(:params) { { start_date: nil, due_date: nil } }

        it 'sets only one date to null' do
          expect(service.synced_epic_params[:start_date]).to eq(nil)
          expect(service.synced_epic_params[:due_date]).to eq(nil)
        end
      end
    end
  end
end
