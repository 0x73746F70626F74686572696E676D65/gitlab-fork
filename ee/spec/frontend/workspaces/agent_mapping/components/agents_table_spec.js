import { GlTable, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import AgentsTable from 'ee_component/workspaces/agent_mapping/components/agents_table.vue';
import {
  AGENT_MAPPING_STATUS_MAPPED,
  AGENT_MAPPING_STATUS_UNMAPPED,
} from 'ee_component/workspaces/agent_mapping/constants';

describe('workspaces/agent_mapping/components/agents_table.vue', () => {
  let wrapper;
  const EMPTY_STATE_MESSAGE = 'No agents found';
  const agents = [
    { name: 'agent-1', mappingStatus: AGENT_MAPPING_STATUS_MAPPED },
    { name: 'agent-1', mappingStatus: AGENT_MAPPING_STATUS_UNMAPPED },
  ];

  const buildWrapper = ({ propsData = {} } = {}, mountFn = shallowMountExtended) => {
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
          mountExtended,
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
            agents,
          },
        },
        mountExtended,
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

    describe('when displayMappingStatus is true', () => {
      it('displays agent status using label', () => {
        buildWrapper(
          {
            propsData: {
              isLoading: false,
              displayMappingStatus: true,
              agents,
            },
          },
          mountExtended,
        );
        const labels = wrapper
          .findAllByTestId('agent-mapping-status-label')
          .wrappers.map((labelWrapper) => labelWrapper.text());

        expect(labels).toEqual(['Allowed', 'Blocked']);
      });
    });

    describe('when displayAgentStatus is false', () => {
      it('does not display agent status using label', () => {
        buildWrapper(
          {
            propsData: {
              isLoading: false,
              mappingStatus: false,
              agents,
            },
          },
          mountExtended,
        );

        expect(wrapper.findAllByTestId('agent-mapping-status-label').length).toBe(0);
      });
    });
  });
});
