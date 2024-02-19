# frozen_string_literal: true

require 'spec_helper'

RSpec.describe QuickActions::TargetService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user).tap { |u| project.add_maintainer(u) } }
  let(:container) { project }
  let(:service) { described_class.new(container: container, current_user: user) }

  describe '#execute' do
    shared_examples 'no target' do |type_iid:|
      it 'returns nil' do
        target = service.execute(type, type_iid)

        expect(target).to be_nil
      end
    end

    shared_examples 'find target' do
      it 'returns the target' do
        found_target = service.execute(type, target_iid)

        expect(found_target).to eq(target)
      end
    end

    shared_examples 'build target' do |type_iid:|
      it 'builds a new target' do
        target = service.execute(type, type_iid)

        expect(target.resource_parent).to eq(container)
        expect(target).to be_new_record
      end
    end

    context 'for issue' do
      let(:target) { create(:issue, project: project) }
      let(:target_iid) { target.iid }
      let(:type) { 'Issue' }

      it_behaves_like 'find target'
      it_behaves_like 'build target', type_iid: nil
      it_behaves_like 'build target', type_iid: -1
    end

    context 'for work item' do
      let(:target) { create(:work_item, :task, project: project) }
      let(:target_iid) { target.iid }
      let(:type) { 'WorkItem' }

      it_behaves_like 'find target'

      context 'when work item belongs to a group' do
        let(:container) { group }
        let(:target) { create(:work_item, :group_level, namespace: group) }

        it_behaves_like 'find target'
      end
    end

    context 'for merge request' do
      let(:target) { create(:merge_request, source_project: project) }
      let(:target_iid) { target.iid }
      let(:type) { 'MergeRequest' }

      it_behaves_like 'find target'
      it_behaves_like 'build target', type_iid: nil
      it_behaves_like 'build target', type_iid: -1
    end

    context 'for commit' do
      let(:project) { create(:project, :repository) }
      let(:target) { project.commit.parent }
      let(:target_iid) { target.sha }
      let(:type) { 'Commit' }

      it_behaves_like 'find target'
      it_behaves_like 'no target', type_iid: 'invalid_sha'

      context 'with nil target_iid' do
        let(:target) { project.commit }
        let(:target_iid) { nil }

        it_behaves_like 'find target'
      end
    end

    context 'for unknown type' do
      let(:type) { 'unknown' }

      it_behaves_like 'no target', type_iid: :unused
    end
  end
end
