import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import GroupProjectsDropdown from 'ee/security_orchestration/components/group_projects_dropdown.vue';

describe('GroupProjectsDropdown', () => {
  let wrapper;
  let requestHandlers;

  const defaultNodes = [
    { id: convertToGraphQLId(TYPENAME_PROJECT, 1), name: '1', fullPath: 'project-1-full-path' },
    { id: convertToGraphQLId(TYPENAME_PROJECT, 2), name: '2', fullPath: 'project-2-full-path' },
  ];

  const defaultNodesIds = defaultNodes.map(({ id }) => id);

  const mapItems = (items) => items.map(({ id, name }) => ({ value: id, text: name }));

  const defaultPageInfo = {
    __typename: 'PageInfo',
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  };

  const mockApolloHandlers = (nodes = defaultNodes, hasNextPage = false) => {
    return {
      getGroupProjects: jest.fn().mockResolvedValue({
        data: {
          id: 1,
          group: {
            id: 2,
            projects: {
              nodes,
              pageInfo: { ...defaultPageInfo, hasNextPage },
            },
          },
        },
      }),
    };
  };

  const createMockApolloProvider = (handlers) => {
    Vue.use(VueApollo);

    requestHandlers = handlers;
    return createMockApollo([[getGroupProjects, requestHandlers.getGroupProjects]]);
  };

  const createComponent = ({ propsData = {}, handlers = mockApolloHandlers() } = {}) => {
    wrapper = shallowMount(GroupProjectsDropdown, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        groupFullPath: 'gitlab-org',
        ...propsData,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const selectAllProjects = () => findDropdown().vm.$emit('select-all');
  const resetAllProjects = () => findDropdown().vm.$emit('reset');

  beforeEach(() => {
    createComponent();
  });

  it('should render loading state', () => {
    expect(findDropdown().props('loading')).toBe(true);
  });

  it('should load group projects', async () => {
    await waitForPromises();
    expect(findDropdown().props('loading')).toBe(false);
    expect(findDropdown().props('items')).toEqual(mapItems(defaultNodes));
  });

  it('should select projects', async () => {
    const [{ id }] = defaultNodes;

    await waitForPromises();
    findDropdown().vm.$emit('select', [id]);
    expect(wrapper.emitted('select')).toEqual([[[getIdFromGraphQLId(id)]]]);
  });

  it('should select all projects', async () => {
    await waitForPromises();
    selectAllProjects();
    expect(wrapper.emitted('select')).toEqual([
      [defaultNodesIds.map((id) => getIdFromGraphQLId(id))],
    ]);
  });

  it('renders default text when loading', () => {
    expect(findDropdown().props('toggleText')).toBe('Select projects');
  });

  describe('selected projects', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selectedProjectsIds: defaultNodesIds,
        },
      });
    });

    it('should be possible to preselect projects', async () => {
      await waitForPromises();
      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);
    });

    it('renders all projects selected text when', async () => {
      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('All projects');
    });

    it('should reset all projects', async () => {
      await waitForPromises();
      resetAllProjects();

      expect(wrapper.emitted('select')).toEqual([[[]]]);
    });
  });

  describe('selected projects that does not exist', () => {
    it('renders default placeholder when selected projects do not exist', async () => {
      createComponent({
        propsData: {
          selectedProjectsIds: ['one', 'two'],
        },
      });

      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('Select projects');
    });

    it('filters selected projects that does not exist', async () => {
      createComponent({
        propsData: {
          selectedProjectsIds: ['one', 'two'],
        },
      });

      await waitForPromises();
      findDropdown().vm.$emit('select', [defaultNodesIds[0]]);

      expect(wrapper.emitted('select')).toEqual([[[getIdFromGraphQLId(defaultNodesIds[0])]]]);
    });
  });

  describe('when there is more than a page of projects', () => {
    describe('when bottom reached on scrolling', () => {
      it('makes a query to fetch more projects', async () => {
        createComponent({ handlers: mockApolloHandlers([], true) });
        await waitForPromises();

        findDropdown().vm.$emit('bottom-reached');
        expect(requestHandlers.getGroupProjects).toHaveBeenCalledTimes(2);
      });

      describe('when the fetch query throws an error', () => {
        it('emits an error event', async () => {
          createComponent({
            handlers: {
              getGroupProjects: jest.fn().mockRejectedValue({}),
            },
          });
          await waitForPromises();
          expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
        });
      });
    });

    describe('when a query is loading a new page of projects', () => {
      it('should render the loading spinner', async () => {
        createComponent({ handlers: mockApolloHandlers([], true) });
        await waitForPromises();

        findDropdown().vm.$emit('bottom-reached');
        await nextTick();

        expect(findDropdown().props('loading')).toBe(true);
      });
    });
  });

  describe('full id format', () => {
    it('should emit full format of id', async () => {
      createComponent({
        propsData: {
          useShortIdFormat: false,
        },
      });

      await waitForPromises();
      selectAllProjects();

      expect(wrapper.emitted('select')).toEqual([[defaultNodesIds]]);
    });

    it('should render selected ids in full format', async () => {
      createComponent({
        propsData: {
          selectedProjectsIds: defaultNodesIds,
          useShortIdFormat: false,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);
    });
  });
});
