# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AwardEmoji, feature_category: :team_planning do
  describe 'validations' do
    context 'custom emoji' do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:emoji) { create(:custom_emoji, name: 'partyparrot', namespace: group) }

      before do
        group.add_maintainer(user)
      end

      it 'accepts custom emoji on epic' do
        epic = create(:epic, group: group)
        new_award = build(:award_emoji, user: user, awardable: epic, name: emoji.name)

        expect(new_award).to be_valid
      end

      it 'accepts custom emoji on subgroup epic' do
        subgroup = create(:group, parent: group)
        epic = create(:epic, group: subgroup)
        new_award = build(:award_emoji, user: user, awardable: epic, name: emoji.name)

        expect(new_award).to be_valid
      end
    end

    context 'when awardable has a sync legacy epic' do
      let_it_be_with_refind(:epic) { create(:epic) }
      let_it_be_with_refind(:work_item) { epic.work_item }
      let_it_be(:user) { create(:user) }
      let_it_be(:emoji_1) { create(:award_emoji, :upvote, awardable: work_item, user: user) }
      let_it_be(:emoji_2) { create(:award_emoji, :downvote, awardable: epic, user: user) }

      context 'and emoji present on sync object from same user' do
        it 'returns error' do
          expect(build(:award_emoji, :upvote, awardable: epic, user: user)).not_to be_valid
          expect(build(:award_emoji, :downvote, awardable: work_item, user: user)).not_to be_valid
        end

        context 'when importing' do
          it 'skips validation' do
            expect(build(:award_emoji, :upvote, awardable: epic, user: user, importing: true)).to be_valid
            expect(build(:award_emoji, :downvote, awardable: work_item, user: user, importing: true)).to be_valid
          end
        end

        context 'when author is ghost user' do
          it 'skips validation' do
            user.update!(user_type: :ghost)
            expect(build(:award_emoji, :upvote, awardable: epic, user: user, importing: true)).to be_valid
            expect(build(:award_emoji, :downvote, awardable: work_item, user: user, importing: true)).to be_valid
          end
        end
      end
    end
  end
end
