import { GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import getClusterAgentsQuery from 'ee/security_dashboard/graphql/queries/cluster_agents.query.graphql';
import ClusterToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/cluster_token.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { projectClusters } from 'ee_jest/security_dashboard/components/mock_data';

Vue.use(VueRouter);
Vue.use(VueApollo);
jest.mock('~/alert');

describe('Cluster Token component', () => {
  let wrapper;
  let router;
  const projectFullPath = 'test/path';
  const defaultProjectClustersQueryResolver = jest.fn().mockResolvedValue(projectClusters);

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = {},
    active = false,
    stubs,
    projectClustersQueryResolver = defaultProjectClustersQueryResolver,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ClusterToken, {
      router,
      apolloProvider: createMockApollo([[getClusterAgentsQuery, projectClustersQueryResolver]]),
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
        projectFullPath,
      },
      stubs,
    });
  };

  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findCheckedIcon = (value) => wrapper.findByTestId(`cluster-icon-${value}`);
  const isOptionChecked = (v) => !findCheckedIcon(v).classes('gl-invisible');

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  describe('default view', () => {
    const findViewSlot = () => wrapper.findByTestId('slot-view');
    const findSuggestionsSlot = () => wrapper.findByTestId('slot-suggestions');
    const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

    const stubs = {
      GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
        template: `
          <div>
            <div data-testid="slot-view">
              <slot name="view"></slot>
            </div>
            <div data-testid="slot-suggestions">
              <slot name="suggestions"></slot>
            </div>
          </div>`,
      }),
    };

    beforeEach(() => {
      createWrapper({
        stubs,
      });
    });

    it('shows the label', () => {
      expect(findViewSlot().text()).toBe('All clusters');
    });

    it('shows the dropdown with correct options', async () => {
      await waitForPromises();

      expect(
        findSuggestionsSlot()
          .text()
          .split('\n')
          .map((s) => s.trim())
          .filter((i) => i),
      ).toEqual(['All clusters', 'primary-agent', 'james-bond-agent', 'jason-bourne-agent']);
    });

    it('shows the loading icon when cluster agents are not yet loaded', async () => {
      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  it('shows an alert on a failed GraphQL request', async () => {
    createWrapper({ projectClustersQueryResolver: jest.fn().mockRejectedValue() });
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({ message: 'Failed to load cluster agents.' });
  });

  describe('item selection', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('toggles the item selection when clicked on', async () => {
      await clickDropdownItem('primary-agent', 'james-bond-agent');

      expect(isOptionChecked('primary-agent')).toBe(true);
      expect(isOptionChecked('james-bond-agent')).toBe(true);
      expect(isOptionChecked('jason-bourne-agent')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All clusters" when that item is selected', async () => {
      await clickDropdownItem('primary-agent', 'ALL');

      expect(isOptionChecked('primary-agent')).toBe(false);
      expect(isOptionChecked('james-bond-agent')).toBe(false);
      expect(isOptionChecked('jason-bourne-agent')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('selects "All clusters" when last selected item is deselected', async () => {
      // Select and deselect "primary-agent"
      await clickDropdownItem('primary-agent', 'primary-agent');

      expect(isOptionChecked('primary-agent')).toBe(false);
      expect(isOptionChecked('james-bond-agent')).toBe(false);
      expect(isOptionChecked('jason-bourne-agent')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      // Select 2 cluster agents
      await clickDropdownItem('primary-agent', 'james-bond-agent');

      expect(spy).toHaveBeenCalledWith({
        clusterAgentId: ['gid://gitlab/Clusters::Agent/2', 'gid://gitlab/Clusters::Agent/007'],
      });
    });
  });

  describe('toggle text', () => {
    const findSlotView = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(() => {
      createWrapper({ mountFn: mountExtended });
    });

    it('shows "primary-agent, james-bond-agent" when primary-agent, james-bond-agent are selected', async () => {
      await clickDropdownItem('primary-agent', 'james-bond-agent');
      expect(findSlotView().text()).toBe('primary-agent, james-bond-agent');
    });

    it('shows "primary-agent, james-bond-agent +1 more" when primary-agent, james-bond-agent, and jason-bourne-agent are selected', async () => {
      await clickDropdownItem('primary-agent', 'james-bond-agent', 'jason-bourne-agent');
      expect(findSlotView().text()).toBe('primary-agent, james-bond-agent +1 more');
    });

    it('shows "primary-agent" when only primary-agent is selected', async () => {
      await clickDropdownItem('primary-agent');
      expect(findSlotView().text()).toBe('primary-agent');
    });
  });

  describe('QuerystringSync component', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'cluster',
        value: ['ALL'],
      });
    });

    it('receives "ALL" when All clusters option is clicked', async () => {
      await clickDropdownItem('ALL');

      expect(findQuerystringSync().props('value')).toEqual(['ALL']);
    });

    it('restores selected items', async () => {
      findQuerystringSync().vm.$emit('input', ['primary-agent', 'james-bond-agent']);

      await nextTick();

      expect(isOptionChecked('primary-agent')).toBe(true);
      expect(isOptionChecked('james-bond-agent')).toBe(true);
      expect(isOptionChecked('jason-bourne-agent')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('emits filters-changed event when restoring', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      findQuerystringSync().vm.$emit('input', ['primary-agent']);

      await waitForPromises();

      expect(spy).toHaveBeenCalledWith({
        clusterAgentId: ['gid://gitlab/Clusters::Agent/2'],
      });
    });
  });
});
