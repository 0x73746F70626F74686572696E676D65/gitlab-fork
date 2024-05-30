import { shallowMount } from '@vue/test-utils';
import { orderBy } from 'lodash';
import BoardFilteredSearch from 'ee/boards/components/board_filtered_search.vue';
import IssueBoardFilteredSpec from 'ee/boards/components/issue_board_filtered_search.vue';
import issueBoardFilters from 'ee/boards/issue_board_filters';
import { mockTokens } from '../mock_data';

jest.mock('ee/boards/issue_board_filters');

describe('IssueBoardFilter', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(IssueBoardFilteredSpec, {
      propsData: {
        boardId: 'gid://gitlab/Board/1',
        filters: {},
      },
      provide: {
        isSignedIn: true,
        releasesFetchPath: '/releases',
        fullPath: 'gitlab-org',
        isGroupBoard: true,
        epicFeatureAvailable: true,
        iterationFeatureAvailable: true,
        healthStatusFeatureAvailable: true,
      },
      mocks: {
        $apollo: {},
      },
    });
  };

  let fetchLabelsSpy;
  let fetchIterationsSpy;
  beforeEach(() => {
    fetchLabelsSpy = jest.fn();
    fetchIterationsSpy = jest.fn();

    issueBoardFilters.mockReturnValue({
      fetchLabels: fetchLabelsSpy,
      fetchIterations: fetchIterationsSpy,
    });
  });

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('finds BoardFilteredSearch', () => {
      expect(wrapper.findComponent(BoardFilteredSearch).exists()).toBe(true);
    });

    it('passes the correct tokens to BoardFilteredSearch including epics', () => {
      const tokens = mockTokens(fetchLabelsSpy, fetchIterationsSpy);

      expect(wrapper.findComponent(BoardFilteredSearch).props('tokens')).toEqual(
        orderBy(tokens, ['title']),
      );
    });
  });
});
