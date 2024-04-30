import Vue from 'vue';
import VueApollo from 'vue-apollo';

import RoadmapFilters from 'ee/roadmap/components/roadmap_filters.vue';
import { PRESET_TYPES, DATE_RANGES } from 'ee/roadmap/constants';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';
import {
  mockSortedBy,
  mockTimeframeInitialDate,
  mockAuthorTokenConfig,
  mockLabelTokenConfig,
  mockMilestoneTokenConfig,
  mockConfidentialTokenConfig,
  mockEpicTokenConfig,
  mockReactionEmojiTokenConfig,
  mockGroupTokenConfig,
} from 'ee_jest/roadmap/mock_data';

import { TEST_HOST } from 'helpers/test_constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { STATUS_ALL, STATUS_CLOSED } from '~/issues/constants';
import { updateHistory } from '~/lib/utils/url_utility';
import {
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
} from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { setLocalSettingsInCache, expectPayload } from '../local_cache_helpers';

jest.mock('~/lib/utils/url_utility', () => ({
  setUrlParams: jest.requireActual('~/lib/utils/url_utility').setUrlParams,
  updateHistory: jest.requireActual('~/lib/utils/url_utility').updateHistory,
}));

Vue.use(VueApollo);

const updateLocalSettingsMutationMock = jest.fn();

describe('RoadmapFilters', () => {
  let wrapper;
  let apolloProvider;

  const createComponent = ({
    presetType = PRESET_TYPES.MONTHS,
    epicsState = STATUS_ALL,
    sortedBy = mockSortedBy,
    groupFullPath = 'gitlab-org',
    groupMilestonesPath = '/groups/gitlab-org/-/milestones.json',
    timeframe = getTimeframeForRangeType({
      timeframeRangeType: DATE_RANGES.THREE_YEARS,
      presetType: PRESET_TYPES.MONTHS,
      initialDate: mockTimeframeInitialDate,
    }),
    filterParams = {},
  } = {}) => {
    apolloProvider = createMockApollo([], {
      Mutation: {
        updateLocalRoadmapSettings: updateLocalSettingsMutationMock,
      },
    });
    setLocalSettingsInCache(apolloProvider, {
      presetType,
      timeframeRangeType: DATE_RANGES.THREE_YEARS,
      sortedBy,
      timeframe,
      epicsState,
      isProgressTrackingActive: true,
      filterParams,
    });

    wrapper = shallowMountExtended(RoadmapFilters, {
      provide: {
        groupFullPath,
        groupMilestonesPath,
      },
      apolloProvider,
    });
  };

  const findSettingsButton = () => wrapper.findByTestId('settings-button');
  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);

  describe('watch', () => {
    describe('urlParams', () => {
      it('updates window URL based on presence of props for state, filtered search and sort criteria', async () => {
        createComponent();
        await waitForPromises();

        expect(global.window.location.href).toBe(
          `${TEST_HOST}/?state=${STATUS_ALL}&sort=start_date_asc&layout=MONTHS&timeframe_range_type=THREE_YEARS&progress=WEIGHT&show_progress=true&show_milestones=true&milestones_type=ALL&show_labels=false`,
        );

        setLocalSettingsInCache(apolloProvider, {
          epicsState: STATUS_CLOSED,
          sortedBy: 'end_date_asc',
          timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
          presetType: PRESET_TYPES.MONTHS,
          filterParams: {
            authorUsername: 'root',
            labelName: ['Bug'],
            milestoneTitle: '4.0',
            confidential: true,
          },
        });

        jest.runOnlyPendingTimers();
        await waitForPromises();

        expect(global.window.location.href).toBe(
          `${TEST_HOST}/?state=${STATUS_CLOSED}&sort=end_date_asc&layout=MONTHS&timeframe_range_type=CURRENT_YEAR&author_username=root&label_name[]=Bug&milestone_title=4.0&confidential=true&progress=WEIGHT&show_progress=true&show_milestones=true&milestones_type=ALL&show_labels=false`,
        );
      });
    });
  });

  describe('template', () => {
    beforeEach(() => {
      updateHistory({ url: TEST_HOST, title: document.title, replace: true });
    });

    it('renders settings button', () => {
      createComponent();

      expect(findSettingsButton().exists()).toBe(true);
    });

    it('emits toggleSettings event on click settings button', () => {
      createComponent();
      findSettingsButton().vm.$emit('click');

      expect(wrapper.emitted('toggleSettings')).toHaveLength(1);
    });

    describe('FilteredSearchBar', () => {
      const mockInitialFilterValue = [
        {
          type: TOKEN_TYPE_AUTHOR,
          value: { data: 'root', operator: '=' },
        },
        {
          type: TOKEN_TYPE_AUTHOR,
          value: { data: 'John', operator: '!=' },
        },
        {
          type: TOKEN_TYPE_LABEL,
          value: { data: 'Bug', operator: '=' },
        },
        {
          type: TOKEN_TYPE_LABEL,
          value: { data: 'Feature', operator: '!=' },
        },
        {
          type: TOKEN_TYPE_MILESTONE,
          value: { data: '4.0' },
        },
        {
          type: TOKEN_TYPE_CONFIDENTIAL,
          value: { data: true },
        },
        {
          type: TOKEN_TYPE_MY_REACTION,
          value: { data: 'thumbs_up', operator: '!=' },
        },
      ];

      it('component is rendered with correct namespace & recent search key', () => {
        createComponent();

        expect(findFilteredSearchBar().exists()).toBe(true);
        expect(findFilteredSearchBar().props('namespace')).toBe('gitlab-org');
        expect(findFilteredSearchBar().props('recentSearchesStorageKey')).toBe('epics');
      });

      it('includes `Author`, `Milestone`, `Confidential`, `Epic`, `Group`, and `Label` tokens when user is not logged in', () => {
        createComponent();

        expect(findFilteredSearchBar().props('tokens')).toEqual([
          mockAuthorTokenConfig,
          mockConfidentialTokenConfig,
          mockEpicTokenConfig,
          mockGroupTokenConfig,
          mockLabelTokenConfig,
          mockMilestoneTokenConfig,
        ]);
      });

      it('includes "Start date" and "Due date" sort options', () => {
        createComponent();

        expect(findFilteredSearchBar().props('sortOptions')).toEqual([
          {
            id: 1,
            title: 'Start date',
            sortDirection: {
              descending: 'start_date_desc',
              ascending: 'start_date_asc',
            },
          },
          {
            id: 2,
            title: 'Due date',
            sortDirection: {
              descending: 'end_date_desc',
              ascending: 'end_date_asc',
            },
          },
        ]);
      });

      it('has initialFilterValue prop set to array of formatted values based on `filterParams`', () => {
        createComponent({
          filterParams: {
            authorUsername: 'root',
            labelName: ['Bug'],
            milestoneTitle: '4.0',
            confidential: true,
            'not[authorUsername]': 'John',
            'not[labelName]': ['Feature'],
            'not[myReactionEmoji]': 'thumbs_up',
          },
        });

        expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(mockInitialFilterValue);
      });

      it('calls `updateLocalRoadmapSettings` mutation with correct payload when `onFilter` event is emitted', async () => {
        const filterParams = {
          authorUsername: 'root',
          confidential: true,
          labelName: ['Bug'],
          milestoneTitle: '4.0',
          'not[authorUsername]': 'John',
          'not[labelName]': ['Feature'],
          'not[myReactionEmoji]': 'thumbs_up',
        };
        createComponent();

        findFilteredSearchBar().vm.$emit('onFilter', mockInitialFilterValue);
        await waitForPromises();

        expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
          ...expectPayload({ filterParams }),
        );
      });

      it('updates sort order when `onSort` event is emitted', async () => {
        createComponent();
        findFilteredSearchBar().vm.$emit('onSort', 'end_date_asc');
        await waitForPromises();

        expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
          ...expectPayload({ sortedBy: 'end_date_asc' }),
        );
      });

      it('does not set filters params when onFilter event is triggered with empty filters array and cleared param set to false', () => {
        createComponent();
        findFilteredSearchBar().vm.$emit('onFilter', [], false);

        expect(updateLocalSettingsMutationMock).not.toHaveBeenCalled();
      });

      describe('when user is logged in', () => {
        beforeEach(() => {
          gon.current_user_id = 1;
          gon.current_user_fullname = 'Administrator';
          gon.current_username = 'root';
          gon.current_user_avatar_url = 'avatar/url';

          createComponent();
        });

        it('includes `Author`, `Milestone`, `Confidential`, `Epic`, `Group`, `Label` and `My-Reaction` tokens', () => {
          expect(findFilteredSearchBar().props('tokens')).toEqual([
            {
              ...mockAuthorTokenConfig,
              preloadedUsers: [
                {
                  id: 1,
                  name: 'Administrator',
                  username: 'root',
                  avatar_url: 'avatar/url',
                },
              ],
            },
            mockConfidentialTokenConfig,
            mockEpicTokenConfig,
            mockGroupTokenConfig,
            mockLabelTokenConfig,
            mockMilestoneTokenConfig,
            mockReactionEmojiTokenConfig,
          ]);
        });
      });
    });
  });
});
