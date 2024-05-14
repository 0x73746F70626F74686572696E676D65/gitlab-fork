import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentMapping from 'ee_component/workspaces/agent_mapping/components/agent_mapping.vue';
import AgentsTable from 'ee_component/workspaces/agent_mapping/components/agents_table.vue';
import GetAvailableAgentsQuery from 'ee_component/workspaces/agent_mapping/components/get_available_agents_query.vue';
import { stubComponent } from 'helpers/stub_component';

describe('workspaces/agent_mapping/components/agent_mapping.vue', () => {
  let wrapper;
  const NAMESPACE = 'foo/bar';

  const buildWrapper = ({ mappedAgentsQueryState = {} } = {}) => {
    wrapper = shallowMount(AgentMapping, {
      provide: {
        namespace: NAMESPACE,
      },
      stubs: {
        GetAvailableAgentsQuery: stubComponent(GetAvailableAgentsQuery, {
          render() {
            return this.$scopedSlots.default?.(mappedAgentsQueryState);
          },
        }),
      },
    });
  };
  const findGetAvailableAgentsQuery = () => wrapper.findComponent(GetAvailableAgentsQuery);
  const findAgentsTable = () => wrapper.findComponent(AgentsTable);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);

  describe('default', () => {
    beforeEach(() => {
      buildWrapper();
    });

    it('does not display an error alert', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('available agents table', () => {
    it('renders GetAvailableAgentsQuery component and passes namespace path', () => {
      buildWrapper();

      expect(findGetAvailableAgentsQuery().props('namespace')).toBe(NAMESPACE);
    });

    describe('when GetAvailableAgentsQuery component emits results event', () => {
      let agents;

      beforeEach(() => {
        buildWrapper();

        agents = [{}];
        findGetAvailableAgentsQuery().vm.$emit('result', { agents });
      });

      it('passes query result to the AgentsTable component', () => {
        expect(findAgentsTable().props('agents')).toBe(agents);
      });
    });

    describe('when GetAvailableAgentsQuery component emits error event', () => {
      beforeEach(() => {
        buildWrapper();

        findGetAvailableAgentsQuery().vm.$emit('error');
      });

      it('displays error as a danger alert', () => {
        expect(findErrorAlert().text()).toContain('Could not load available agents');
      });

      it('does not render AgentsTable component', () => {
        expect(findAgentsTable().exists()).toBe(false);
      });
    });

    it('renders AgentsTable component', () => {
      buildWrapper();

      expect(findAgentsTable().exists()).toBe(true);
    });

    it('provides empty state message to the AgentsTable component', () => {
      buildWrapper();

      expect(findAgentsTable().props('emptyStateMessage')).toBe(
        'This group has no available agents. Select the All agents tab and allow at least one agent.',
      );
    });

    it('provides loading state from the GetAvailableAgentsQuery to the AgentsTable component', () => {
      buildWrapper({ mappedAgentsQueryState: { loading: true } });

      expect(findAgentsTable().props('isLoading')).toBe(true);
    });
  });
});
