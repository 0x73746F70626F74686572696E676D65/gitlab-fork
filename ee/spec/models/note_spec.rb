# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Note, feature_category: :team_planning do
  include ::EE::GeoHelpers

  it_behaves_like 'an editable mentionable with EE-specific mentions' do
    subject { create :note, noteable: issue, project: issue.project }

    let(:issue) { create(:issue, project: create(:project, :repository)) }
    let(:backref_text) { issue.gfm_reference }
    let(:set_mentionable_text) { ->(txt) { subject.note = txt } }
  end

  describe 'validation' do
    describe 'confidentiality' do
      context 'for a new note' do
        let(:note_params) { { confidential: true, noteable: noteable, project: noteable.project } }

        subject(:note) { build(:note, **note_params) }

        context 'when noteable is a epic' do
          let_it_be(:noteable) { create(:epic) }

          it 'can not be set confidential' do
            expect(note).to be_valid
          end
        end
      end
    end
  end

  describe 'callbacks' do
    describe '#touch_noteable' do
      it 'calls #touch on the noteable' do
        noteable = create(:issue)
        note = build(:note, project: noteable.project, noteable: noteable)

        expect(note).to receive(:touch_noteable).and_call_original
        expect(note.noteable).to receive(:touch)

        note.save!
      end

      context 'when noteable is an epic' do
        let_it_be(:noteable) { create(:epic) }
        let(:note) { build(:note, project: nil, noteable: noteable) }
        let(:noteable_association) { note.association(:noteable) }

        before do
          allow(noteable_association).to receive(:loaded?).and_return(object_loaded)
          allow(note).to receive(:touch_noteable).and_call_original
        end

        context 'when noteable is loaded' do
          let(:object_loaded) { true }

          it 'calls #touch and #sync_work_item_updated_at on the noteable' do
            expect(note.noteable).to receive(:touch)
            expect(note.noteable).to receive(:sync_work_item_updated_at)

            note.save!
          end
        end

        context 'when noteable is not loaded' do
          let(:object_loaded) { false }

          it 'calls #touch and #sync_work_item_updated_at on the noteable' do
            expect_any_instance_of(::Epic) do |epic|
              expect(epic).to receive(:touch)
              expect(epic).to receive(:sync_work_item_updated_at)
            end

            note.save!
          end
        end
      end
    end
  end

  describe '#ensure_namespace_id' do
    context 'for an epic note' do
      let_it_be(:epic) { create(:epic) }

      it 'copies the group_id of the epic' do
        note = build(:note, noteable: epic, project: nil)

        note.valid?

        expect(note.namespace_id).to eq(epic.group_id)
      end

      context 'when noteable is changed' do
        let_it_be(:another_epic) { create(:epic) }

        it 'updates the namespace_id' do
          note = create(:note, noteable: epic, project: nil)

          note.noteable = another_epic
          note.valid?

          expect(note.namespace_id).to eq(another_epic.group_id)
        end
      end
    end
  end

  describe '#readable_by?' do
    let(:owner) { create(:group_member, :owner, group: group, user: create(:user)).user }
    let(:guest) { create(:group_member, :guest, group: group, user: create(:user)).user }
    let(:reporter) { create(:group_member, :reporter, group: group, user: create(:user)).user }
    let(:maintainer) { create(:group_member, :maintainer, group: group, user: create(:user)).user }
    let(:non_member) { create(:user) }

    let(:group) { create(:group, :public) }
    let(:epic) { create(:epic, group: group, author: owner, created_at: 1.day.ago) }

    before do
      stub_licensed_features(epics: true)
    end

    context 'note created after epic' do
      let(:note) { create(:system_note, noteable: epic, created_at: 1.minute.ago) }

      it_behaves_like 'users with note access' do
        let(:users) { [owner, reporter, maintainer, guest, non_member, nil] }
      end

      context 'when group is private' do
        let(:group) { create(:group, :private) }

        it_behaves_like 'users with note access' do
          let(:users) { [owner, reporter, maintainer, guest] }
        end

        it 'returns visible but not readable for a non-member user' do
          expect(note.system_note_visible_for?(non_member)).to be_truthy
          expect(note.readable_by?(non_member)).to be_falsy
        end

        it 'returns visible but not readable for a nil user' do
          expect(note.system_note_visible_for?(nil)).to be_truthy
          expect(note.readable_by?(nil)).to be_falsy
        end
      end
    end

    context 'when note is older than epic' do
      let(:note) { create(:system_note, noteable: epic, created_at: 2.days.ago) }

      it_behaves_like 'users with note access' do
        let(:users) { [owner, reporter, maintainer] }
      end

      it_behaves_like 'users without note access' do
        let(:users) { [guest, non_member, nil] }
      end

      context 'when group is private' do
        let(:group) { create(:group, :private) }

        it_behaves_like 'users with note access' do
          let(:users) { [owner, reporter, maintainer] }
        end

        it_behaves_like 'users without note access' do
          let(:users) { [guest, non_member, nil] }
        end
      end
    end
  end

  describe '#system_note_with_references?' do
    [:relate_epic, :unrelate_epic].each do |type|
      it "delegates #{type} system note to the cross-reference regex" do
        note = create(:note, :system)
        create(:system_note_metadata, note: note, action: type)

        expect(note).to receive(:matches_cross_reference_regex?).and_return(false)

        note.system_note_with_references?
      end
    end
  end

  describe '#resource_parent' do
    it 'returns group for epic notes' do
      group = create(:group)
      note = create(:note_on_epic, noteable: create(:epic, group: group))

      expect(note.resource_parent).to eq(group)
    end
  end

  describe '.by_humans' do
    it 'excludes notes by bots and service users' do
      user_note = create(:note)
      create(:system_note)
      create(:note, author: create(:user, :bot))
      create(:note, author: create(:user, :service_user))

      expect(described_class.by_humans).to match_array([user_note])
    end
  end

  describe '.count_for_vulnerability_id' do
    it 'counts notes by vulnerability id' do
      vulnerability_1 = create(:vulnerability)
      vulnerability_2 = create(:vulnerability)

      create(:note, noteable: vulnerability_1, project: vulnerability_1.project)
      create(:note, noteable: vulnerability_2, project: vulnerability_2.project)
      create(:note, noteable: vulnerability_2, project: vulnerability_2.project)

      expect(described_class.count_for_vulnerability_id([vulnerability_1.id, vulnerability_2.id])).to eq(vulnerability_1.id => 1, vulnerability_2.id => 2)
    end
  end

  describe '#skip_notification?' do
    subject(:skip_notification?) { note.skip_notification? }

    context 'when there is no review' do
      context 'when the note is not for vulnerability' do
        let(:note) { build(:note) }

        it { is_expected.to be_falsey }
      end

      context 'when the note is for vulnerability' do
        let(:note) { build(:note, :on_vulnerability) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when the review exists' do
      context 'when the note is not for vulnerability' do
        let(:note) { build(:note, :with_review) }

        it { is_expected.to be_truthy }
      end

      context 'when the note is for vulnerability' do
        let(:note) { build(:note, :with_review, :on_vulnerability) }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#updated_by_or_author' do
    subject(:updated_by_or_author) { note.updated_by_or_author }

    context 'when updated_by is nil' do
      let(:note) { create(:note, updated_by: nil) }

      it 'returns the author' do
        expect(updated_by_or_author).to be(note.author)
      end
    end

    context 'when updated_by is present' do
      let(:user) { create(:user) }
      let(:note) { create(:note, updated_by: user) }

      it 'returns the last user who updated the note' do
        expect(updated_by_or_author).to be(user)
      end
    end
  end

  describe '#search_index', feature_category: :global_search do
    let(:note) { create(:note) }
    let(:search_index) { instance_double(::Search::NoteIndex) }

    it 'delegates to Search::IndexRegistry' do
      expect(::Search::IndexRegistry).to receive(:index_for_namespace)
        .with(namespace: note.project.namespace, type: ::Search::NoteIndex)
        .and_return(search_index)

      expect(note.search_index).to eq(search_index)
    end

    context 'when not assigned to a project' do
      let(:user) { create(:user) }
      let(:note) { described_class.new(author: user) }

      it 'uses author namespace' do
        expect(::Search::IndexRegistry).to receive(:index_for_namespace)
          .with(namespace: user.namespace, type: ::Search::NoteIndex)
          .and_return(search_index)

        expect(note.search_index).to eq(search_index)
      end
    end
  end

  describe '.note_starting_with' do
    it 'returns a note matching the prefix' do
      create(:note)
      create(:note, note: 'non-matching prefix note')
      create(:note, note: 'non-matching')
      matching_note = create(:note, note: 'prefix note')

      expect(described_class.note_starting_with('prefix')).to contain_exactly(matching_note)
    end
  end
end
