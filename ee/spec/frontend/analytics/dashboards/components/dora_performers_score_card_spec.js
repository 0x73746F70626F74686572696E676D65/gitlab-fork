import { GlAlert, GlCard, GlSkeletonLoader } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import DoraPerformersScoreCard from 'ee/analytics/dashboards/components/dora_performers_score_card.vue';
import DoraPerformersScore from 'ee/analytics/dashboards/components/dora_performers_score.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getDoraPerformersGroup from 'ee/analytics/dashboards/graphql/get_dora_performers_group.query.graphql';

Vue.use(VueApollo);

describe('DoraPerformersScoreCard', () => {
  const mockGroup = {
    __typename: TYPENAME_GROUP,
    id: 'gid://gitlab/Llama/22',
    name: 'Llama',
  };

  let wrapper;
  let mockApollo;

  const createWrapper = ({ group = mockGroup } = {}) => {
    mockApollo = createMockApollo([
      [getDoraPerformersGroup, jest.fn().mockResolvedValue({ data: { group } })],
    ]);

    wrapper = shallowMountExtended(DoraPerformersScoreCard, {
      apolloProvider: mockApollo,
      propsData: {
        data: { namespace: 'fullpath' },
      },
      stubs: {
        GlCard,
      },
    });

    return waitForPromises();
  };

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPanelTitle = () => wrapper.findByTestId('dora-performers-score-panel-title');
  const findDoraPerformersScore = () => wrapper.findComponent(DoraPerformersScore);

  describe('loading group', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('group failed to load', () => {
    beforeEach(() => createWrapper({ group: null }));

    it('renders the default panel title', () => {
      expect(findPanelTitle().text()).toBe('DORA performers score');
    });

    it('renders an error alert', () => {
      expect(findAlert().text()).toBe('Failed to load Group: fullpath');
    });
  });

  describe('group loaded successfully', () => {
    beforeEach(() => createWrapper());

    it('renders a panel title with the group name', () => {
      expect(findPanelTitle().text()).toBe('DORA performers score for Llama group');
    });

    it('renders the dora performers score chart', () => {
      expect(findDoraPerformersScore().props()).toMatchObject({ data: { namespace: 'fullpath' } });
    });
  });
});
