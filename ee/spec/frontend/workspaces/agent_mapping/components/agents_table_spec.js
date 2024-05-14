import { GlTable, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount, mount } from '@vue/test-utils';
import AgentsTable from 'ee_component/workspaces/agent_mapping/components/agents_table.vue';

describe('workspaces/agent_mapping/components/agents_table.vue', () => {
  let wrapper;
  const EMPTY_STATE_MESSAGE = 'No agents found';

  const buildWrapper = ({ propsData = {} } = {}, mountFn = shallowMount) => {
    wrapper = mountFn(AgentsTable, {
      propsData: {
        agents: [],
        emptyStateMessage: EMPTY_STATE_MESSAGE,
        isLoading: false,
        ...propsData,
      },
    });
  };
  const findAgentsTable = () => wrapper.findComponent(GlTable);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      buildWrapper({
        propsData: {
          isLoading: true,
        },
      });
    });

    it('displays skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not display agents table', () => {
      expect(findAgentsTable().exists()).toBe(false);
    });
  });

  describe('when is not loading and agents are available', () => {
    describe('with agents', () => {
      beforeEach(() => {
        buildWrapper({
          propsData: {
            isLoading: false,
            agents: [{}],
          },
        });
      });

      it('does not display skeleton loader', () => {
        expect(findSkeletonLoader().exists()).toBe(false);
      });

      it('displays agents table', () => {
        expect(findAgentsTable().exists()).toBe(true);
      });
    });

    describe('with no agents', () => {
      beforeEach(() => {
        buildWrapper(
          {
            propsData: {
              isLoading: false,
              agents: [],
            },
          },
          mount,
        );
      });

      it('does not display skeleton loader', () => {
        expect(findSkeletonLoader().exists()).toBe(false);
      });

      it('displays agents table', () => {
        expect(findAgentsTable().exists()).toBe(true);
      });

      it('displays empty message in agents table', () => {
        expect(findAgentsTable().text()).toContain(EMPTY_STATE_MESSAGE);
      });
    });
  });

  describe('with agents', () => {
    beforeEach(() => {
      buildWrapper(
        {
          propsData: {
            isLoading: false,
            agents: [{ name: 'agent-1' }],
          },
        },
        mount,
      );
    });

    it('does not display skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('displays agents table', () => {
      expect(findAgentsTable().exists()).toBe(true);
    });

    it('displays agents list', () => {
      expect(findAgentsTable().text()).toContain('agent-1');
    });
  });
});
