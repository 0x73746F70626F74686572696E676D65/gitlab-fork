# frozen_string_literal: true

RSpec.shared_examples 'ee protected ref access' do |association|
  let_it_be(:described_instance) { described_class.model_name.singular }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:protected_ref) { create(association, project: project) }
  let_it_be(:protected_ref_fk) { "#{association}_id" }
  let_it_be(:test_group) { create(:group) }
  let_it_be(:test_user) { create(:user) }

  before_all do
    create(:project_group_link, group: group, project: project)
  end

  describe '#type' do
    using RSpec::Parameterized::TableSyntax

    where(
      :group,            :group_id, :user,            :user_id, :expectation
    ) do
      ref(:test_group) | nil      | nil             | nil     | :group
      nil              | 1        | nil             | nil     | :group
      nil              | nil      | ref(:test_user) | nil     | :user
      nil              | nil      | nil             | 1       | :user
    end

    with_them do
      let(:access_level) do
        build(described_instance, group_id: group_id, user_id: user_id).tap do |access_level|
          access_level.group = group if group
          access_level.user = user if user
        end
      end

      subject { access_level.type }

      it { is_expected.to eq(expectation) }
    end
  end

  describe '#humanize' do
    using RSpec::Parameterized::TableSyntax

    where(
      :group,            :group_id, :user,            :user_id, :expectation
    ) do
      ref(:test_group) | nil      | nil             | nil     | lazy { test_group.name }
      nil              | 1        | nil             | nil     | 'Group'
      nil              | nil      | ref(:test_user) | nil     | lazy { test_user.name }
      nil              | nil      | nil             | 1       | 'User'
    end

    with_them do
      let(:access_level) do
        build(described_instance, group_id: group_id, user_id: user_id).tap do |access_level|
          access_level.group = group if group
          access_level.user = user if user
        end
      end

      subject { access_level.humanize }

      it { is_expected.to eq(expectation) }
    end
  end
end

RSpec.shared_examples 'protected ref access configured for users' do |association|
  let_it_be(:project) { create(:project) }
  let_it_be(:protected_ref) { create(association, project: project) }

  describe '#check_access' do
    let_it_be(:current_user) { create(:user) }

    let(:access_level) { nil }
    let(:user) { nil }
    let(:group) { nil }

    before_all do
      project.add_maintainer(current_user)
    end

    subject do
      described_class.new(
        association => protected_ref,
        user: user,
        group: group,
        access_level: access_level
      )
    end

    context 'when user is assigned' do
      context 'when current_user is the user' do
        let(:user) { current_user }

        it { expect(subject.check_access(current_user)).to eq(true) }
      end

      context 'when current_user is another user' do
        let(:user) { create(:user) }

        it { expect(subject.check_access(current_user)).to eq(false) }
      end
    end
  end
end

RSpec.shared_examples 'protected ref access configured for groups' do |association|
  let_it_be(:project) { create(:project) }
  let_it_be(:protected_ref) { create(association, project: project) }

  describe '#check_access' do
    let_it_be(:current_user) { create(:user) }

    let(:access_level) { nil }
    let(:user) { nil }
    let(:group) { nil }

    before_all do
      project.add_maintainer(current_user)
    end

    subject do
      described_class.new(
        association => protected_ref,
        user: user,
        group: group,
        access_level: access_level
      )
    end

    context 'when group is assigned' do
      let(:group) { create(:group) }

      context 'when current_user is in the group' do
        before do
          group.add_developer(current_user)
        end

        it { expect(subject.check_access(current_user)).to eq(true) }
      end

      context 'when current_user is not in the group' do
        it { expect(subject.check_access(current_user)).to eq(false) }
      end
    end
  end
end
