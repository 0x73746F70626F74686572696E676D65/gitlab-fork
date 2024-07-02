# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::DiscussionsListService, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :repository, :private, group: group) }
  let_it_be(:milestone) { create(:milestone, project: project) }
  let_it_be(:label) { create(:label, project: project) }
  let_it_be(:label_2) { create(:label, project: project) }

  let(:finder_params_for_issuable) { {} }

  subject(:discussions_service) { described_class.new(current_user, issuable, finder_params_for_issuable) }

  describe 'fetching notes for incidents' do
    let_it_be(:issuable) { create(:incident, project: project) }

    it_behaves_like 'listing issuable discussions', user_role: :guest, internal_discussions: 1, total_discussions: 7
  end

  describe 'fetching notes for epics' do
    let_it_be(:issuable) { create(:epic, group: group) }

    before do
      stub_licensed_features(epics: true)
    end

    it 'returns same discussions for epic and epic work item' do
      epic_discussions = described_class.new(current_user, issuable, finder_params_for_issuable).execute
      work_item_discussions = described_class.new(
        current_user, issuable.sync_object, finder_params_for_issuable
      ).execute

      expect(epic_discussions.count).to eq(work_item_discussions.count)
    end

    it_behaves_like 'listing issuable discussions', user_role: :guest, internal_discussions: 1, total_discussions: 5

    describe 'fetching notes for epic work item' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:issuable) { epic.work_item }

      before do
        stub_licensed_features(epics: true)
      end

      it_behaves_like 'listing issuable discussions', user_role: :guest, internal_discussions: 1, total_discussions: 5
    end
  end

  describe 'fetching notes for vulnerabilities' do
    let_it_be(:issuable) { create(:vulnerability, project: project) }

    before do
      stub_licensed_features(security_dashboard: true)

      group.add_developer(current_user)

      create(:note, system: true, project: issuable.project, noteable: issuable)
      create(:note, system: true, project: issuable.project, noteable: issuable)
      create(:note, system: true, project: issuable.project, noteable: issuable)

      disc_start = create(:discussion_note_on_issue, noteable: issuable, project: issuable.project, note: "a comment")
      create(:note,
        discussion_id: disc_start.discussion_id, noteable: issuable,
        project: issuable.project, note: "reply to a comment")
    end

    it "returns all notes" do
      discussions = discussions_service.execute
      expect(discussions.count).to eq(4)
    end

    context 'with paginated results' do
      let(:finder_params_for_issuable) { { per_page: 2 } }
      let(:next_page_cursor) { { cursor: discussions_service.paginator.cursor_for_next_page } }

      it "returns next page notes" do
        next_page_discussions_service = described_class.new(current_user, issuable,
          finder_params_for_issuable.merge(next_page_cursor))
        discussions = next_page_discussions_service.execute

        expect(discussions.count).to eq(2)
        expect(discussions.last.notes.map(&:note)).to match_array(["a comment", "reply to a comment"])
      end
    end

    context 'and system notes only' do
      let(:finder_params_for_issuable) { { notes_filter: UserPreference::NOTES_FILTERS[:only_activity] } }

      it "returns system notes" do
        discussions = discussions_service.execute

        expect(discussions.count { |disc| disc.notes.any?(&:system) }).to be > 0
        expect(discussions.count { |disc| !disc.notes.any?(&:system) }).to eq(0)
      end
    end

    context 'and user comments only' do
      let(:finder_params_for_issuable) { { notes_filter: UserPreference::NOTES_FILTERS[:only_comments] } }

      it "returns user comments" do
        discussions = discussions_service.execute

        expect(discussions.count { |disc| disc.notes.any?(&:system) }).to eq(0)
        expect(discussions.count { |disc| !disc.notes.any?(&:system) }).to be > 0
      end
    end
  end
end
