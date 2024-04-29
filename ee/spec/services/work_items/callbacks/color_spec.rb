# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Color, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:group) { create(:group, reporters: reporter) }
  let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group, author: user) }
  let_it_be_with_reload(:color) { create(:color, work_item: work_item, color: '#1068bf') }
  let_it_be(:error_class) { ::WorkItems::Widgets::BaseService::WidgetError }

  let(:current_user) { reporter }
  let(:params) { {} }
  let(:callback) { described_class.new(issuable: work_item, current_user: current_user, params: params) }

  def work_item_color
    work_item.reload.color&.color.to_s
  end

  describe '#after_initialize' do
    subject(:after_initialize_callback) { callback.after_initialize }

    shared_examples 'work item and color is unchanged' do
      it 'does not change work item color value' do
        expect { after_initialize_callback }
          .to not_change { work_item_color }
          .and not_change { work_item.updated_at }
      end

      it 'does not set synced_epic_params' do
        after_initialize_callback

        expect(callback.synced_epic_params).to be_empty
      end
    end

    shared_examples 'color is updated' do |color|
      it 'updates work item color value' do
        expect { after_initialize_callback }.to change { work_item_color }.to(color)
      end

      it 'sets synced_epic_params' do
        after_initialize_callback

        expect(callback.synced_epic_params[:color].to_s).to eq(color)
      end
    end

    shared_examples 'raises a WidgetError' do
      it { expect { after_initialize_callback }.to raise_error(error_class, message) }
    end

    context 'when epic_colors feature is licensed' do
      before do
        stub_licensed_features(epic_colors: true)
      end

      context 'when color param is present' do
        context 'when color param is valid' do
          let(:params) { { color: '#454545' } }

          it_behaves_like 'color is updated', '#454545'
        end

        context 'when widget does not exist in new type' do
          let(:params) { {} }

          before do
            allow(callback).to receive(:excluded_in_new_type?).and_return(true)
            work_item.color = color
          end

          it "removes the work item's color" do
            expect { callback.after_initialize }.to change { work_item.reload.color }.from(color).to(nil)
          end
        end
      end

      context 'when color param is not present' do
        let(:params) { {} }

        it_behaves_like 'work item and color is unchanged'
      end

      context 'when color is same as work item color' do
        let(:params) { { color: '#1068bf' } }

        it_behaves_like 'work item and color is unchanged'
      end

      context 'when color param is nil' do
        let(:params) { { color: nil } }

        it_behaves_like 'raises a WidgetError' do
          let(:message) { "Color can't be blank" }
        end
      end

      context 'when user cannot admin_work_item' do
        let(:current_user) { user }
        let(:params) { { color: '#1068bf' } }

        it_behaves_like 'work item and color is unchanged'
      end
    end

    context 'when epic_colors feature is unlicensed' do
      before do
        stub_licensed_features(epic_colors: false)
      end

      it_behaves_like 'work item and color is unchanged'
    end
  end

  describe '#after_save_commit' do
    subject(:after_save_commit_callback) { callback.after_save_commit }

    it "does not create system notes when color didn't change" do
      expect { after_save_commit_callback }.to not_change { work_item.notes.count }
    end

    context 'when color was reset' do
      before do
        allow(work_item.color).to receive(:destroyed?).and_return(true)
      end

      it 'creates system note' do
        expect { after_save_commit_callback }.to change { work_item.notes.count }.by(1)

        expect(work_item.notes.first.note).to eq("removed color `#{color.color}`")
      end
    end

    context 'when color was updated' do
      before do
        allow(work_item.color).to receive_message_chain(:previous_changes, :include?).and_return(true)
      end

      it 'creates system note' do
        expect { after_save_commit_callback }.to change { work_item.notes.count }.by(1)

        expect(work_item.notes.first.note).to eq("set color to `#{color.color}`")
      end
    end
  end
end
