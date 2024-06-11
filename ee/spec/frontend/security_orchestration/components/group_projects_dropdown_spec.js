import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import GroupProjectsDropdown from 'ee/security_orchestration/components/group_projects_dropdown.vue';

describe('GroupProjectsDropdown', () => {
  let wrapper;
  let requestHandlers;

  const GROUP_FULL_PATH = 'gitlab-org';

  const generateMockNode = (ids) =>
    ids.map((id) => ({
      id: convertToGraphQLId(TYPENAME_PROJECT, id),
      name: `${id}`,
      fullPath: `project-${id}-full-path`,
      repository: { rootRef: 'main' },
    }));

  const defaultNodes = generateMockNode([1, 2]);

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

  const createComponent = ({
    propsData = {},
    handlers = mockApolloHandlers(),
    stubs = {},
  } = {}) => {
    wrapper = shallowMountExtended(GroupProjectsDropdown, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        groupFullPath: GROUP_FULL_PATH,
        ...propsData,
      },
      stubs,
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

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
    expect(wrapper.emitted('select')).toEqual([[[defaultNodes[0]]]]);
  });

  it('renders default text when loading', () => {
    expect(findDropdown().props('toggleText')).toBe('Select projects');
  });

  it('should select full projects with full id format', async () => {
    createComponent({
      propsData: {
        useShortIdFormat: false,
      },
    });

    const [{ id }] = defaultNodes;

    await waitForPromises();
    findDropdown().vm.$emit('select', [id]);
    expect(wrapper.emitted('select')).toEqual([[[defaultNodes[0]]]]);
  });

  describe('selected projects', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selected: defaultNodesIds,
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
  });

  describe('selected projects that does not exist', () => {
    it('renders default placeholder when selected projects do not exist', async () => {
      createComponent({
        propsData: {
          selected: ['one', 'two'],
        },
      });

      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('Select projects');
    });

    it('filters selected projects that does not exist', async () => {
      createComponent({
        propsData: {
          selected: ['one', 'two'],
          useShortIdFormat: false,
        },
      });

      await waitForPromises();
      findDropdown().vm.$emit('select', [defaultNodesIds[0]]);

      expect(wrapper.emitted('select')).toEqual([[[defaultNodes[0]]]]);
    });
  });

  describe('select single project', () => {
    it('support single selection mode', async () => {
      createComponent({
        propsData: {
          multiple: false,
        },
      });

      await waitForPromises();

      findDropdown().vm.$emit('select', defaultNodesIds[0]);
      expect(wrapper.emitted('select')).toEqual([[defaultNodes[0]]]);
    });

    it('should render single selected project', async () => {
      createComponent({
        propsData: {
          multiple: false,
          selected: defaultNodesIds[0],
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(defaultNodesIds[0]);
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

      it.each`
        hasNextPage | expectedText
        ${true}     | ${'1, 2'}
        ${false}    | ${'All projects'}
      `(
        'selects all projects only when all projects loaded',
        async ({ hasNextPage, expectedText }) => {
          createComponent({
            propsData: {
              selected: defaultNodesIds,
            },
            handlers: mockApolloHandlers(defaultNodes, hasNextPage),
          });

          await waitForPromises();

          expect(findDropdown().props('toggleText')).toBe(expectedText);
        },
      );

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
    it('should render selected ids in full format', async () => {
      createComponent({
        propsData: {
          selected: defaultNodesIds,
          useShortIdFormat: false,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);
    });
  });

  describe('validation', () => {
    it('renders default dropdown when validation passes', () => {
      createComponent({
        propsData: {
          state: true,
        },
      });

      expect(findDropdown().props('variant')).toEqual('default');
      expect(findDropdown().props('category')).toEqual('primary');
    });

    it('renders danger dropdown when validation passes', () => {
      createComponent();

      expect(findDropdown().props('variant')).toEqual('danger');
      expect(findDropdown().props('category')).toEqual('secondary');
    });
  });

  describe('select all', () => {
    it('selects all projects', async () => {
      createComponent();
      await waitForPromises();

      findDropdown().vm.$emit('select-all');

      expect(wrapper.emitted('select')).toEqual([[defaultNodes]]);
    });

    it('resets all projects', async () => {
      createComponent();
      await waitForPromises();

      findDropdown().vm.$emit('reset');

      expect(wrapper.emitted('select')).toEqual([[[]]]);
    });
  });

  describe('selection after search', () => {
    it('should add projects to existing selection after search', async () => {
      const moreNodes = generateMockNode([1, 2, 3, 44, 444, 4444]);
      createComponent({
        propsData: {
          selected: defaultNodesIds,
        },
        handlers: mockApolloHandlers(moreNodes),
        stubs: {
          GlCollapsibleListbox,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);

      findDropdown().vm.$emit('search', '4');
      await waitForPromises();

      expect(requestHandlers.getGroupProjects).toHaveBeenCalledWith({
        fullPath: GROUP_FULL_PATH,
        projectIds: null,
        search: '4',
      });

      await waitForPromises();
      await wrapper.findByTestId(`listbox-item-${moreNodes[3].id}`).vm.$emit('select', true);

      expect(wrapper.emitted('select')).toEqual([[[...defaultNodes, moreNodes[3]]]]);
    });
  });
});
