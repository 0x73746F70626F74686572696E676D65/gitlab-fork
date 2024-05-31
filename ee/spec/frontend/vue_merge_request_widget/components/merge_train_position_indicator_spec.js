import { nextTick } from 'vue';
import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MergeTrainPositionIndicator from 'ee/vue_merge_request_widget/components/merge_train_position_indicator.vue';
import { trimText } from 'helpers/text_helper';

describe('MergeTrainPositionIndicator', () => {
  let wrapper;
  let mockToast;

  const findLink = () => wrapper.findComponent(GlLink);

  const createComponent = (props, mergeTrainsViz = false) => {
    wrapper = shallowMount(MergeTrainPositionIndicator, {
      propsData: {
        mergeTrainsPath: 'namespace/project/-/merge_trains',
        ...props,
      },
      provide: {
        glFeatures: {
          mergeTrainsViz,
        },
      },
      mocks: {
        $toast: {
          show: mockToast,
        },
      },
    });
  };

  describe('with mergeTrainsViz enabled', () => {
    it('should show message when position is higher than 1', () => {
      createComponent(
        {
          mergeTrainIndex: 3,
          mergeTrainsCount: 5,
        },
        true,
      );

      expect(trimText(wrapper.text())).toBe(
        'This merge request is #4 of 5 in queue. View merge train details.',
      );
      expect(findLink().attributes('href')).toBe('namespace/project/-/merge_trains');
    });

    it('should show message when the position is 1', () => {
      createComponent({ mergeTrainIndex: 0, mergeTrainsCount: 0 }, true);

      expect(trimText(wrapper.text())).toBe(
        'A new merge train has started and this merge request is the first of the queue. View merge train details.',
      );
      expect(findLink().attributes('href')).toBe('namespace/project/-/merge_trains');
    });

    it('should not render when merge request is not in train', () => {
      createComponent(
        {
          mergeTrainIndex: null,
          mergeTrainsCount: 1,
        },
        true,
      );

      expect(wrapper.text()).toBe('');
    });
  });

  describe('with mergeTrainsViz disabled', () => {
    it('should show message when position is higher than 1', () => {
      createComponent({ mergeTrainIndex: 3 });

      expect(trimText(wrapper.text())).toBe(
        'Added to the merge train. There are 4 merge requests waiting to be merged',
      );
      expect(findLink().exists()).toBe(false);
    });

    it('should show message when the position is 1', () => {
      createComponent({ mergeTrainIndex: 0 });

      expect(trimText(wrapper.text())).toBe(
        'A new merge train has started and this merge request is the first of the queue.',
      );
      expect(findLink().exists()).toBe(false);
    });

    it('should not render when merge request is not in train', () => {
      createComponent(
        {
          mergeTrainIndex: null,
          mergeTrainsCount: 1,
        },
        true,
      );

      expect(wrapper.text()).toBe('');
    });
  });

  describe('when position in the train changes', () => {
    beforeEach(() => {
      mockToast = jest.fn();
    });

    it.each([0, 1, 2])(
      'shows a toast when removed from position %d in the train',
      async (index) => {
        createComponent({ mergeTrainIndex: index });

        expect(mockToast).not.toHaveBeenCalled();

        wrapper.setProps({ mergeTrainIndex: null });
        await nextTick();

        expect(mockToast).toHaveBeenCalledTimes(1);
        expect(mockToast).toHaveBeenCalledWith('Merge request was removed from the merge train.');
      },
    );

    it.each([0, 1, 2])('shows no toast when added to train in position %d', async (index) => {
      createComponent({ mergeTrainIndex: null });

      expect(mockToast).not.toHaveBeenCalled();

      wrapper.setProps({ mergeTrainIndex: index });
      await nextTick();

      expect(mockToast).not.toHaveBeenCalled();
    });
  });
});
