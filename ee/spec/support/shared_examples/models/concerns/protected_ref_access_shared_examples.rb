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

  describe 'Validations:' do
    let(:access_user_id) { nil }
    let(:access_group_id) { nil }
    let(:access_user) { nil }
    let(:access_group) { nil }
    let(:importing) { false }

    subject do
      build(
        described_class.model_name.singular.to_sym,
        association => protected_ref,
        user_id: access_user_id,
        group_id: access_group_id,
        importing: importing
      ).tap do |instance|
        # We need to assign manually after building because AR sets the
        # association to nil if the fk attributes are passed including nil.
        instance.user = access_user if access_user
        instance.group = access_group if access_group
      end
    end

    shared_context 'when feature :protected_refs_for_users is enabled' do
      before do
        allow(project).to receive(:feature_available?).with(:protected_refs_for_users).and_return(true)
      end
    end

    shared_context 'when feature :protected_refs_for_users is disabled' do
      before do
        allow(project).to receive(:feature_available?).with(:protected_refs_for_users).and_return(false)
      end
    end

    shared_context 'and not a role based access level' do
      before do
        allow(subject).to receive(:role?).and_return(false)
      end
    end

    shared_context 'and is a role based access level' do
      before do
        allow(subject).to receive(:role?).and_return(true)
      end
    end

    shared_examples 'validates user_id and group_id absence' do
      it { is_expected.to validate_absence_of(:group_id) }
      it { is_expected.to validate_absence_of(:user_id) }
    end

    shared_examples 'does not validate user_id and group_id absence' do
      it { is_expected.not_to validate_absence_of(:group_id) }
      it { is_expected.not_to validate_absence_of(:user_id) }
    end

    shared_examples 'validates user and group exist' do
      context 'and group_id is present' do
        let(:access_group_id) { 0 }

        it do
          is_expected.not_to be_valid
          expect(subject.errors.where(:group, :blank)).to be_present
        end
      end

      context 'and user_id is present' do
        let(:access_user_id) { 0 }

        it do
          is_expected.not_to be_valid
          expect(subject.errors.where(:user, :blank)).to be_present
        end
      end
    end

    shared_examples 'does not validate user and group exist' do
      context 'and group_id is present' do
        let(:access_group_id) { group.id }

        it { is_expected.not_to validate_presence_of(:group) }
      end

      context 'and user_id is present' do
        let(:access_user_id) { user.id }

        it { is_expected.not_to validate_presence_of(:user) }
      end
    end

    shared_examples 'validates user and group membership' do
      context 'and group is present' do
        let(:access_group) { group }

        before do
          allow(subject).to receive(:validate_group_membership)
          subject.valid?
        end

        it { is_expected.to have_received(:validate_group_membership) }
      end

      context 'and user is present' do
        let(:access_user) { user }

        before do
          allow(subject).to receive(:validate_user_membership)
          subject.valid?
        end

        it { is_expected.to have_received(:validate_user_membership) }
      end
    end

    shared_examples 'does not validate user and group membership' do
      context 'and group is present' do
        let(:access_group) { group }

        before do
          allow(subject).to receive(:validate_group_membership)
          subject.valid?
        end

        it { is_expected.not_to have_received(:validate_group_membership) }
      end

      context 'and user is present' do
        let(:access_user) { user }

        before do
          allow(subject).to receive(:validate_user_membership)
          subject.valid?
        end

        it { is_expected.not_to have_received(:validate_user_membership) }
      end
    end

    context 'when not importing' do
      let(:importing) { false }

      context 'when feature :protected_refs_for_users is enabled' do
        include_context 'when feature :protected_refs_for_users is enabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'validates user and group exist'
          it_behaves_like 'validates user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'validates user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end

      context 'when feature :protected_refs_for_users is disabled' do
        include_context 'when feature :protected_refs_for_users is disabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'validates user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'validates user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end
    end

    context 'when importing' do
      let(:importing) { true }

      context 'when feature :protected_refs_for_users is enabled' do
        include_context 'when feature :protected_refs_for_users is enabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end

      context 'when feature :protected_refs_for_users is disabled' do
        include_context 'when feature :protected_refs_for_users is disabled'

        context 'and not a role based access level' do
          include_context 'and not a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end

        context 'and is a role based access level' do
          include_context 'and is a role based access level'

          it_behaves_like 'does not validate user_id and group_id absence'
          it_behaves_like 'does not validate user and group exist'
          it_behaves_like 'does not validate user and group membership'
        end
      end
    end
  end

  describe '#type' do
    using RSpec::Parameterized::TableSyntax

    where(
      :group,            :group_id, :user,            :user_id, :expectation
    ) do
      ref(:test_group) | nil      | nil             | nil     | :group
      nil              | 0        | nil             | nil     | :group
      nil              | nil      | ref(:test_user) | nil     | :user
      nil              | nil      | nil             | 0       | :user
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
      nil              | 0        | nil             | nil     | 'Group'
      nil              | nil      | ref(:test_user) | nil     | lazy { test_user.name }
      nil              | nil      | nil             | 0       | 'User'
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

  describe '#check_access(current_user, current_project)' do
    let_it_be(:current_user) { create(:user) }

    let(:user) { nil }
    let(:group) { nil }
    let(:current_project) { project }
    let(:described_instance) do
      described_class.new(
        association => protected_ref,
        user: user,
        group: group
      )
    end

    before_all do
      project.add_maintainer(current_user)
    end

    subject do
      described_instance.check_access(current_user, current_project)
    end

    context 'when user is assigned' do
      context 'when current_user is the user' do
        let(:user) { current_user }

        context 'when user is a project member' do
          it { is_expected.to eq(true) }
        end

        context 'when user is not a project member' do
          before do
            allow(project).to receive(:member?).with(user).and_return(false)
          end

          it { is_expected.to eq(false) }
        end
      end

      context 'when current_user is another user' do
        let(:user) { create(:user) }

        it { is_expected.to eq(false) }
      end
    end
  end
end

RSpec.shared_examples 'protected ref access configured for groups' do |association|
  let_it_be(:project) { create(:project) }
  let_it_be(:protected_ref) { create(association, project: project) }

  describe '#check_access(current_user, current_project)' do
    let_it_be(:current_user) { create(:user) }

    let(:user) { nil }
    let(:group) { nil }
    let(:current_project) { project }
    let(:described_instance) do
      described_class.new(
        association => protected_ref,
        user: user,
        group: group
      )
    end

    before_all do
      project.add_maintainer(current_user)
    end

    subject do
      described_instance.check_access(current_user, current_project)
    end

    context 'when group is assigned' do
      let(:group) { create(:group) }

      context 'when current_user is in the group' do
        before do
          group.add_developer(current_user)
        end

        it { is_expected.to eq(true) }
      end

      context 'when current_user is not in the group' do
        it { is_expected.to eq(false) }
      end
    end
  end
end
