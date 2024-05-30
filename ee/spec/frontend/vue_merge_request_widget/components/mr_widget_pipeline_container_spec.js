import { shallowMount } from '@vue/test-utils';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import { mockStore } from 'jest/vue_merge_request_widget/mock_data';
import waitForPromises from 'helpers/wait_for_promises';

import MrWidgetPipelineContainer from '~/vue_merge_request_widget/components/mr_widget_pipeline_container.vue';
import MrWidgetContainer from '~/vue_merge_request_widget/components/mr_widget_container.vue';
import MergeTrainPositionIndicator from 'ee/vue_merge_request_widget/components/merge_train_position_indicator.vue';

describe('MrWidgetPipelineContainer', () => {
  let wrapper;

  const createComponent = (options) => {
    wrapper = shallowMount(MrWidgetPipelineContainer, {
      propsData: {
        mr: { ...mockStore },
      },
      stubs: {
        MrWidgetContainer: stubComponent(MrWidgetContainer, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
      ...options,
    });
  };

  describe('merge train indicator', () => {
    it('should render the merge train indicator', async () => {
      createComponent();

      await waitForPromises();

      expect(wrapper.findComponent(MergeTrainPositionIndicator).exists()).toBe(true);
    });
  });
});
