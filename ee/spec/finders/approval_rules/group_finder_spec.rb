# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::GroupFinder, feature_category: :source_code_management do
  let_it_be_with_reload(:rule) { create(:approval_project_rule) }
  let_it_be(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }

  let_it_be(:public_group) { create(:group, name: 'public_group', organization: organization) }
  let_it_be(:private_inaccessible_group) do
    create(:group, :private, name: 'private_inaccessible_group', organization: organization)
  end

  let_it_be(:private_accessible_group) do
    create(:group, :private, name: 'private_accessible_group', owners: user, organization: organization)
  end

  let_it_be(:private_accessible_subgroup) do
    create(:group, :private, parent: private_accessible_group, name: 'private_accessible_subgroup')
  end

  let_it_be(:private_shared_group) do
    create(:group, :private, name: 'private_shared_group', organization: organization)
  end

  let_it_be(:private_shared_group_link) do
    create(:project_group_link, project: rule.project, group: private_shared_group)
  end

  let_it_be(:public_shared_group) { create(:group, name: 'public_shared_group', organization: organization) }
  let_it_be(:public_shared_group_link) do
    create(:project_group_link, project: rule.project, group: public_shared_group)
  end

  subject { described_class.new(rule, user) }

  context 'when with inaccessible groups' do
    before do
      rule.groups = [public_group, private_inaccessible_group, private_accessible_group, private_accessible_subgroup,
        private_shared_group]
    end

    it 'returns groups' do
      expect(subject.visible_groups).to contain_exactly(
        public_group, private_accessible_group, private_accessible_subgroup
      )
      expect(subject.hidden_groups).to contain_exactly(private_inaccessible_group, private_shared_group)
      expect(subject.contains_hidden_groups?).to eq(true)
    end

    context 'when user is a member of the project' do
      let(:project_user) { create :user }

      before do
        rule.project.add_developer(project_user)
        private_accessible_group.add_developer(project_user)
      end

      describe '#hidden_groups' do
        subject { described_class.new(rule, project_user).hidden_groups }

        it 'returns rule groups that the user cannot access except shared groups' do
          expect(subject).to contain_exactly(private_inaccessible_group)
        end

        context 'when the show_private_groups_as_approvers flag is disabled' do
          before do
            stub_feature_flags(show_private_groups_as_approvers: false)
          end

          it 'returns rule groups that the user cannot access' do
            expect(subject).to contain_exactly(private_inaccessible_group, private_shared_group)
          end
        end
      end
    end

    context 'when user is an admin', :enable_admin_mode do
      subject { described_class.new(rule, create(:admin)) }

      it 'returns groups' do
        expect(subject.visible_groups).to contain_exactly(
          public_group,
          private_accessible_group,
          private_accessible_subgroup,
          private_inaccessible_group,
          private_shared_group
        )
        expect(subject.hidden_groups).to be_empty
        expect(subject.contains_hidden_groups?).to eq(false)
      end
    end

    context 'when user is not authorized' do
      subject { described_class.new(rule, nil) }

      it 'returns only public groups' do
        expect(subject.visible_groups).to contain_exactly(
          public_group
        )
        expect(subject.hidden_groups).to contain_exactly(
          private_accessible_group, private_accessible_subgroup, private_inaccessible_group, private_shared_group
        )
        expect(subject.contains_hidden_groups?).to eq(true)
      end
    end

    context 'avoid N+1 query', :request_store do
      it 'avoids N+1 database queries' do
        rule.reload

        control = ActiveRecord::QueryRecorder.new { subject.visible_groups }

        # Clear cached association and request cache
        rule.reload
        RequestStore.clear!

        rule.groups << create(
          :group,
          :private,
          parent: private_accessible_group,
          name: 'private_accessible_subgroup2',
          organization: organization
        )

        expect { described_class.new(rule, user).visible_groups }.not_to exceed_query_limit(control)
      end
    end
  end

  context 'when without inaccessible groups' do
    before do
      rule.groups = [public_group, private_accessible_group, private_accessible_subgroup]
    end

    it 'returns groups' do
      expect(subject.visible_groups).to contain_exactly(
        public_group, private_accessible_group, private_accessible_subgroup
      )
      expect(subject.hidden_groups).to be_empty
      expect(subject.contains_hidden_groups?).to eq(false)
    end
  end
end
