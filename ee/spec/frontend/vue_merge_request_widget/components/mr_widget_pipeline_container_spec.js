import { shallowMount } from '@vue/test-utils';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import { mockStore } from 'jest/vue_merge_request_widget/mock_data';
import waitForPromises from 'helpers/wait_for_promises';

import { STATUS_OPEN } from '~/issues/constants';
import MrWidgetPipelineContainer from '~/vue_merge_request_widget/components/mr_widget_pipeline_container.vue';
import MrWidgetContainer from '~/vue_merge_request_widget/components/mr_widget_container.vue';
import MergeTrainPositionIndicator from 'ee/vue_merge_request_widget/components/merge_train_position_indicator.vue';

describe('MrWidgetPipelineContainer', () => {
  let wrapper;

  const createComponent = ({ store, ...options } = {}) => {
    wrapper = shallowMount(MrWidgetPipelineContainer, {
      propsData: {
        mr: { ...store, ...mockStore },
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
    it('should render merge train indicator', async () => {
      createComponent({
        store: {
          mergeRequestState: STATUS_OPEN,
          mergeTrainIndex: 0,
          mergeTrainsCount: 1,
          mergeTrainsPath: '/train/1',
        },
      });

      await waitForPromises();

      expect(wrapper.findComponent(MergeTrainPositionIndicator).props()).toEqual({
        mergeRequestState: STATUS_OPEN,
        mergeTrainIndex: 0,
        mergeTrainsCount: 1,
        mergeTrainsPath: '/train/1',
      });
    });
  });
});
