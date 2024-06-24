import { GlLabel } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import WorkItemLabels from '~/work_items/components/work_item_labels.vue';
import { workItemByIidResponseFactory } from 'jest/work_items/mock_data';

Vue.use(VueApollo);

const workItemId = 'gid://gitlab/WorkItem/1';

describe('WorkItemLabels component', () => {
  let wrapper;

  const createComponent = ({
    canUpdate = true,
    isGroup = false,
    workItemQueryHandler = jest.fn().mockResolvedValue(workItemByIidResponseFactory()),
    workItemIid = '1',
    fullPath = 'test-project-path',
    issuesListPath = 'test-project-path/issues',
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemLabels, {
      apolloProvider: createMockApollo([[workItemByIidQuery, workItemQueryHandler]]),
      provide: {
        canAdminLabel: true,
        isGroup,
        issuesListPath,
        labelsManagePath: 'test-project-path/labels',
      },
      propsData: {
        fullPath,
        workItemId,
        workItemIid,
        canUpdate,
        workItemType: 'epic',
      },
    });
  };

  const findScopedLabel = () =>
    wrapper.findAllComponents(GlLabel).filter((label) => label.props('scoped'));

  describe('allows scoped labels', () => {
    it.each([true, false])('= %s', async (allowsScopedLabels) => {
      const workItemQueryHandler = jest
        .fn()
        .mockResolvedValue(workItemByIidResponseFactory({ allowsScopedLabels }));
      createComponent({ workItemQueryHandler });
      await waitForPromises();

      expect(findScopedLabel().exists()).toBe(allowsScopedLabels);
    });
  });
});
