import Vue, { nextTick } from 'vue';
import { GlCollapsibleListbox } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import SppSelector from 'ee/security_orchestration/components/policies/spp_selector.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getProjectSPPSuggestions from 'ee/security_orchestration/graphql/queries/get_project_spp_suggestions.query.graphql';
import getGroupSPPSuggestions from 'ee/security_orchestration/graphql/queries/get_group_spp_suggestions.query.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

let querySpy;

const defaultProjectSelectorProps = {
  disabled: false,
  items: [],
  selected: '',
  toggleText: 'Choose a project',
  noResultsText: 'Enter at least three characters to search',
};

const defaultQueryVariables = {
  after: '',
  first: 20,
  fullPath: 'path/to/namespace',
  onlyLinked: false,
  search: 'abc',
};

const defaultPageInfo = {
  __typename: 'PageInfo',
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: null,
  endCursor: null,
};

const querySuccess = (type) => ({
  data: {
    [type]: {
      id: '1',
      securityPolicyProjectSuggestions: {
        nodes: [
          {
            id: 'gid://gitlab/Project/5000162',
            name: 'Pages Test Again',
            nameWithNamespace: 'mixed-vulnerabilities-01 / Pages Test Again',
          },
        ],
        pageInfo: {
          __typename: 'PageInfo',
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'a',
          endCursor: 'z',
        },
      },
    },
  },
});

const queryRepeat = (type) => ({
  data: {
    [type]: {
      id: '2',
      securityPolicyProjectSuggestions: {
        nodes: [
          {
            id: 'gid://gitlab/Project/5000163',
            name: 'Pages Test Again',
            nameWithNamespace: 'mixed-vulnerabilities-01 / Pages Test Again',
          },
        ],
        pageInfo: {
          __typename: 'PageInfo',
          hasNextPage: true,
          hasPreviousPage: false,
          startCursor: 'a',
          endCursor: 'z',
        },
      },
    },
  },
});

const queryError = {
  errors: [
    {
      message: 'test',
      locations: [[{ line: 1, column: 58 }]],
      extensions: {
        value: null,
        problems: [{ path: [], explanation: 'Expected value to not be null' }],
      },
    },
  ],
};

const mockGetProjectSpp = (type = NAMESPACE_TYPES.PROJECT) => ({
  empty: {
    data: {
      [type]: {
        id: '3',
        securityPolicyProjectSuggestions: { nodes: [], pageInfo: defaultPageInfo },
      },
    },
  },
  error: queryError,
  success: querySuccess(type),
  repeat: queryRepeat(type),
});

const createMockApolloProvider = (queryResolver) => {
  Vue.use(VueApollo);
  return createMockApollo([
    [getProjectSPPSuggestions, queryResolver.project],
    [getGroupSPPSuggestions, queryResolver.group],
  ]);
};

describe('SppSelector Component', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findErrorMessage = () => wrapper.findByTestId('error-message');

  const createWrapper = ({ queryResolver, propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(SppSelector, {
      apolloProvider: createMockApolloProvider(queryResolver),
      propsData: {
        ...propsData,
      },
      provide: {
        namespacePath: 'path/to/namespace',
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
    });
  };

  describe('rendering', () => {
    beforeEach(() => {
      querySpy = jest.fn().mockResolvedValue(mockGetProjectSpp().success);
      createWrapper({
        propsData: { headerText: 'Test header' },
        queryResolver: { project: querySpy },
      });
    });

    it('renders the project selector', () => {
      expect(findListbox().props()).toMatchObject(defaultProjectSelectorProps);
    });

    it('renders custom header', () => {
      expect(findListbox().props('headerText')).toBe('Test header');
    });
  });

  describe('project level', () => {
    beforeEach(() => {
      querySpy = jest.fn().mockResolvedValue(mockGetProjectSpp().success);
      createWrapper({ queryResolver: { project: querySpy } });
    });

    it('does not query when the search query is less than three characters', async () => {
      findListbox().vm.$emit('searched', '');
      await waitForPromises();
      expect(querySpy).not.toHaveBeenCalled();
    });

    it('does query when the search query is more than three characters', async () => {
      findListbox().vm.$emit('search', 'abc');
      await waitForPromises();
      expect(querySpy).toHaveBeenCalledTimes(1);
      expect(querySpy).toHaveBeenCalledWith(defaultQueryVariables);
    });

    it('does query when the bottom is reached', async () => {
      expect(querySpy).toHaveBeenCalledTimes(0);
      await findListbox().vm.$emit('search', 'abc');
      expect(findListbox().props('searching')).toBe(true);
      await waitForPromises();
      expect(querySpy).toHaveBeenCalledTimes(1);
      querySpy.mockResolvedValue(mockGetProjectSpp().repeat);
      await findListbox().vm.$emit('bottom-reached');
      expect(findListbox().props('infiniteScrollLoading')).toBe(true);
      await waitForPromises();

      expect(findListbox().props('infiniteScrollLoading')).toBe(false);
      expect(findListbox().props('searching')).toBe(false);

      expect(querySpy).toHaveBeenCalledTimes(2);
      expect(querySpy).toHaveBeenCalledWith({
        ...defaultQueryVariables,
        after: 'z',
      });
    });

    it('emits on "projectClicked"', async () => {
      findListbox().vm.$emit('search', 'Pages');
      await waitForPromises();

      const project = { id: 'gid://gitlab/Project/5000162' };
      findListbox().vm.$emit('select', project.id);
      expect(wrapper.emitted('projectClicked')).toStrictEqual([
        [
          mockGetProjectSpp().success.data[NAMESPACE_TYPES.PROJECT].securityPolicyProjectSuggestions
            .nodes[0],
        ],
      ]);
    });
  });

  describe('group level', () => {
    beforeEach(() => {
      querySpy = jest.fn().mockResolvedValue(mockGetProjectSpp(NAMESPACE_TYPES.GROUP).success);
      createWrapper({
        queryResolver: { group: querySpy },
        provide: { namespaceType: NAMESPACE_TYPES.GROUP },
      });
    });

    it('does query when the search query is more than three characters', async () => {
      findListbox().vm.$emit('search', 'abc');
      await waitForPromises();
      expect(querySpy).toHaveBeenCalledTimes(1);
      expect(querySpy).toHaveBeenCalledWith(defaultQueryVariables);
    });

    it('emits on "projectClicked"', async () => {
      findListbox().vm.$emit('search', 'Pages');
      await waitForPromises();

      const project = { id: 'gid://gitlab/Project/5000162' };
      findListbox().vm.$emit('select', project.id);
      expect(wrapper.emitted('projectClicked')).toStrictEqual([
        [
          mockGetProjectSpp(NAMESPACE_TYPES.GROUP).success.data[NAMESPACE_TYPES.GROUP]
            .securityPolicyProjectSuggestions.nodes[0],
        ],
      ]);
    });
  });

  describe.each([NAMESPACE_TYPES.PROJECT, NAMESPACE_TYPES.GROUP])(
    'other states for %s level',
    (type) => {
      it('notifies project selector of search error', async () => {
        querySpy = jest.fn().mockResolvedValue(mockGetProjectSpp(type).error);
        createWrapper({ queryResolver: { [type]: querySpy }, provide: { namespaceType: type } });
        await nextTick();
        findListbox().vm.$emit('search', 'abc');
        await waitForPromises();
        expect(findErrorMessage().exists()).toBe(true);
        expect(findListbox().props()).toMatchObject({
          ...defaultProjectSelectorProps,
          noResultsText: 'Sorry, no projects matched your search',
        });
      });

      it('notifies project selector of no results', async () => {
        querySpy = jest.fn().mockResolvedValue(mockGetProjectSpp(type).empty);
        createWrapper({ queryResolver: { [type]: querySpy }, provide: { namespaceType: type } });
        await nextTick();
        findListbox().vm.$emit('search', 'abc');
        await waitForPromises();
        expect(findErrorMessage().exists()).toBe(false);
        expect(findListbox().props()).toMatchObject({
          ...defaultProjectSelectorProps,
          noResultsText: 'Sorry, no projects matched your search',
        });
      });
    },
  );
});
