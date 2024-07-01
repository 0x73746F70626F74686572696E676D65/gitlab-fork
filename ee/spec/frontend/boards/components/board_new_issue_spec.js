import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import BoardNewIssue from 'ee/boards/components/board_new_issue.vue';
import currentIterationQuery from 'ee/boards/graphql/board_current_iteration.query.graphql';
import BoardNewItem from '~/boards/components/board_new_item.vue';
import groupBoardQuery from '~/boards/graphql/group_board.query.graphql';

import { mockList, mockGroupProjects, mockGroupBoardResponse } from 'jest/boards/mock_data';
import {
  mockGroupBoardCurrentIterationResponse,
  mockGroupBoardNoIterationResponse,
  currentIterationQueryResponse,
} from '../mock_data';

Vue.use(VueApollo);

const groupBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupBoardResponse);
const currentIterationBoardQueryHandlerSuccess = jest
  .fn()
  .mockResolvedValue(mockGroupBoardCurrentIterationResponse);
const noIterationBoardQueryHandlerSuccess = jest
  .fn()
  .mockResolvedValue(mockGroupBoardNoIterationResponse);
const currentIterationQueryHandlerSuccess = jest
  .fn()
  .mockResolvedValue(currentIterationQueryResponse);

const createComponent = ({
  isGroupBoard = true,
  data = { selectedProject: mockGroupProjects[0] },
  provide = {},
  boardQueryHandler = groupBoardQueryHandlerSuccess,
} = {}) => {
  const mockApollo = createMockApollo([
    [groupBoardQuery, boardQueryHandler],
    [currentIterationQuery, currentIterationQueryHandlerSuccess],
  ]);
  return shallowMount(BoardNewIssue, {
    apolloProvider: mockApollo,
    propsData: {
      list: mockList,
      boardId: 'gid://gitlab/Board/1',
    },
    data: () => data,
    provide: {
      groupId: 1,
      fullPath: mockGroupProjects[0].fullPath,
      weightFeatureAvailable: false,
      boardWeight: null,
      isGroupBoard,
      boardType: isGroupBoard ? 'group' : 'project',
      isEpicBoard: false,
      ...provide,
    },
    stubs: {
      BoardNewItem,
    },
  });
};

describe('Issue boards new issue form', () => {
  let wrapper;

  const findBoardNewItem = () => wrapper.findComponent(BoardNewItem);

  it('does not fetch current iteration and cadence by default', async () => {
    wrapper = createComponent();

    await nextTick();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await nextTick();
    expect(currentIterationQueryHandlerSuccess).not.toHaveBeenCalled();
  });

  it('fetches current iteration and cadence when board scope is set to current iteration without a cadence', async () => {
    wrapper = createComponent({ boardQueryHandler: currentIterationBoardQueryHandlerSuccess });

    await waitForPromises();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await waitForPromises();
    expect(currentIterationQueryHandlerSuccess).toHaveBeenCalled();
    expect(wrapper.emitted('addNewIssue')).toEqual([
      [
        expect.objectContaining({
          iterationCadenceId: 'gid://gitlab/Iterations::Cadence/1',
          iterationWildcardId: 'CURRENT',
        }),
      ],
    ]);
  });

  it('excludes iteration when board is scoped to No iteration', async () => {
    wrapper = createComponent({ boardQueryHandler: noIterationBoardQueryHandlerSuccess });

    await waitForPromises();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await waitForPromises();

    expect(wrapper.emitted('addNewIssue')).toEqual([
      [
        expect.not.objectContaining({
          iterationWildcardId: null,
          iterationId: null,
          iterationCadenceId: null,
        }),
      ],
    ]);
  });
});
