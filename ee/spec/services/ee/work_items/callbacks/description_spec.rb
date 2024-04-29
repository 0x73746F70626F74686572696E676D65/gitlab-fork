# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Description, feature_category: :portfolio_management do
  let_it_be(:random_user) { create(:user) }
  let_it_be(:author) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }

  let(:params) { { description: 'updated description' } }
  let(:current_user) { author }
  let(:work_item) do
    create(
      :work_item,
      author: author,
      project: project,
      description: 'old description',
      last_edited_at: Date.yesterday,
      last_edited_by: random_user
    )
  end

  describe '#after_initialize' do
    let(:service) { described_class.new(issuable: work_item, current_user: current_user, params: params) }

    subject(:after_initialize_callback) { service.after_initialize }

    shared_examples 'sets synced_epic_params' do
      it 'set the synced_epic_params' do
        subject

        expect(service.synced_epic_params[:description]).to eq(params[:description])
        expect(service.synced_epic_params[:description_html]).to eq(work_item.description_html)
      end
    end

    shared_examples 'does not set synced_epic_params' do
      it 'does not set the synced_epic_params' do
        subject

        expect(service.synced_epic_params[:description]).to be_nil
        expect(service.synced_epic_params[:description_html]).to be_nil
      end
    end

    context 'when user has permission to update description' do
      context 'when user is work item author' do
        let(:current_user) { author }

        it_behaves_like 'sets synced_epic_params'
      end

      context 'when user is a project reporter' do
        let(:current_user) { reporter }

        it_behaves_like 'sets synced_epic_params'
      end

      context 'when description is nil' do
        let(:current_user) { author }
        let(:params) { { description: nil } }

        it_behaves_like 'sets synced_epic_params'
      end

      context 'when description is empty' do
        let(:current_user) { author }
        let(:params) { { description: '' } }

        it_behaves_like 'sets synced_epic_params'
      end

      context 'when description param is not present' do
        let(:params) { {} }

        it_behaves_like 'does not set synced_epic_params'
      end
    end

    context 'when user does not have permission to update description' do
      context 'when user is a project guest' do
        let(:current_user) { guest }

        it_behaves_like 'does not set synced_epic_params'
      end

      context 'with private project' do
        let_it_be(:project) { create(:project) }

        context 'when user is work item author' do
          let(:current_user) { author }

          it_behaves_like 'does not set synced_epic_params'
        end
      end
    end
  end
end
