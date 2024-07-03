import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormSelect } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import projectWorkItemTypesQueryResponse from 'test_fixtures/graphql/work_items/project_work_item_types.query.graphql.json';
import groupWorkItemTypesQueryResponse from 'test_fixtures/graphql/work_items/group_work_item_types.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CreateWorkItem from '~/work_items/components/create_work_item.vue';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import WorkItemColor from 'ee/work_items/components/work_item_color.vue';
import WorkItemRolledupDates from 'ee/work_items/components/work_item_rolledup_dates.vue';
import { WORK_ITEM_TYPE_ENUM_EPIC } from '~/work_items/constants';
import groupWorkItemTypesQuery from '~/work_items/graphql/group_work_item_types.query.graphql';
import projectWorkItemTypesQuery from '~/work_items/graphql/project_work_item_types.query.graphql';
import createWorkItemMutation from '~/work_items/graphql/create_work_item.mutation.graphql';
import groupWorkItemByIidQuery from '~/work_items/graphql/group_work_item_by_iid.query.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import { resolvers } from '~/graphql_shared/issuable_client';
import {
  createWorkItemMutationResponse,
  createWorkItemQueryResponse,
} from 'jest/work_items/mock_data';

Vue.use(VueApollo);

describe('Create work item component', () => {
  let wrapper;
  let mockApollo;
  const workItemTypeEpicId = 'gid://gitlab/WorkItems::Type/8';

  const createWorkItemSuccessHandler = jest.fn().mockResolvedValue(createWorkItemMutationResponse);

  const projectWorkItemQuerySuccessHandler = jest
    .fn()
    .mockResolvedValue(createWorkItemQueryResponse);
  const groupWorkItemQuerySuccessHandler = jest.fn().mockResolvedValue(createWorkItemQueryResponse);

  const findHealthStatusWidget = () => wrapper.findComponent(WorkItemHealthStatus);
  const findColorWidget = () => wrapper.findComponent(WorkItemColor);
  const findRolledupDatesWidget = () => wrapper.findComponent(WorkItemRolledupDates);
  const findSelect = () => wrapper.findComponent(GlFormSelect);

  const createComponent = ({
    props = {},
    isGroup = false,
    mutationHandler = createWorkItemSuccessHandler,
    workItemTypeName = WORK_ITEM_TYPE_ENUM_EPIC,
  } = {}) => {
    mockApollo = createMockApollo(
      [
        [groupWorkItemByIidQuery, groupWorkItemQuerySuccessHandler],
        [workItemByIidQuery, projectWorkItemQuerySuccessHandler],
        [createWorkItemMutation, mutationHandler],
      ],
      resolvers,
      { typePolicies: { Project: { merge: true } } },
    );

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: isGroup ? groupWorkItemTypesQuery : projectWorkItemTypesQuery,
      variables: { fullPath: 'full-path', name: workItemTypeName },
      data: isGroup
        ? {
            ...groupWorkItemTypesQueryResponse.data,
          }
        : {
            ...projectWorkItemTypesQueryResponse.data,
          },
    });

    wrapper = shallowMount(CreateWorkItem, {
      apolloProvider: mockApollo,
      propsData: {
        workItemTypeName,
        ...props,
      },
      provide: {
        fullPath: 'full-path',
        isGroup,
        hasIssuableHealthStatusFeature: false,
      },
    });
  };

  const initialiseComponentAndSelectWorkItem = async ({
    mutationHandler = createWorkItemSuccessHandler,
  } = {}) => {
    createComponent({ mutationHandler });

    await waitForPromises();

    findSelect().vm.$emit('input', workItemTypeEpicId);
    await waitForPromises();
  };

  const mockCurrentUser = {
    id: 1,
    name: 'Administrator',
    username: 'root',
    avatar_url: 'avatar/url',
  };

  beforeEach(() => {
    gon.current_user_id = mockCurrentUser.id;
    gon.current_user_fullname = mockCurrentUser.name;
    gon.current_username = mockCurrentUser.username;
    gon.current_user_avatar_url = mockCurrentUser.avatar_url;
  });

  describe('Create work item widgets for epic work item type', () => {
    beforeEach(async () => {
      await initialiseComponentAndSelectWorkItem();
    });

    it('renders the work item health status widget', () => {
      expect(findHealthStatusWidget().exists()).toBe(true);
    });

    it('renders the work item color widget', () => {
      expect(findColorWidget().exists()).toBe(true);
    });

    it('renders the work item rolled up dates widget', () => {
      expect(findRolledupDatesWidget().exists()).toBe(true);
    });
  });
});
