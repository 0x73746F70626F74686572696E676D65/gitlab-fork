# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::WorkItemsController, feature_category: :team_planning do
  describe 'DescriptionDiffActions' do
    let_it_be(:group) { create(:group, :public) }
    let(:group_params) { { group_id: group, iid: issuable.iid } }

    context 'when issuable is an issue type issue' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:issue, :group_level, namespace: group) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }

        let(:base_params) { group_params }
      end
    end

    context 'when work item is an issue type issue' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:work_item, :group_level, namespace: group) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }

        let(:base_params) { group_params }
      end
    end

    context 'when issuable is a task/work_item' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:work_item, :group_level, :task, namespace: group) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }

        let(:base_params) { group_params }
      end
    end
  end
end
