# frozen_string_literal: true

RSpec.shared_examples 'ee protected ref access' do |association|
  let_it_be(:described_instance) { described_class.model_name.singular }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:protected_ref) { create(association, project: project) }
  let_it_be(:protected_ref_fk) { "#{association}_id" }

  before_all do
    create(:project_group_link, group: group, project: project)
  end

  describe '#type' do
    context 'when group is present and group_id is nil' do
      let(:access_level) { build(described_instance, group: build(:group)) }

      it 'returns :group' do
        expect(access_level.type).to eq(:group)
      end
    end

    context 'when group_id is present and group is nil' do
      let(:access_level) { build(described_instance, group_id: 1) }

      it 'returns :group' do
        expect(access_level.type).to eq(:group)
      end
    end

    context 'when user is present and user_id is nil' do
      let(:access_level) { build(described_instance, user: build(:user)) }

      it 'returns :user' do
        expect(access_level.type).to eq(:user)
      end
    end

    context 'when user_id is present and user is nil' do
      let(:access_level) { build(described_instance, user_id: 1) }

      it 'returns :user' do
        expect(access_level.type).to eq(:user)
      end
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
