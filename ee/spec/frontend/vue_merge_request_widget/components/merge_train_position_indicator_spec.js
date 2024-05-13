import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MergeTrainPositionIndicator from 'ee/vue_merge_request_widget/components/merge_train_position_indicator.vue';
import { trimText } from 'helpers/text_helper';

describe('MergeTrainPositionIndicator', () => {
  let wrapper;

  const findLink = () => wrapper.findComponent(GlLink);

  const createComponent = (propsData, mergeTrainsViz = false) => {
    wrapper = shallowMount(MergeTrainPositionIndicator, {
      propsData: {
        mergeTrainsPath: 'namespace/project/-/merge_trains',
        mergeTrainsCount: 0,
        ...propsData,
      },
      provide: {
        glFeatures: {
          mergeTrainsViz,
        },
      },
    });
  };

  describe('with mergeTrainsViz enabled', () => {
    it('should render the correct message', () => {
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

    it('should change the merge train message when the position is 1', () => {
      createComponent({ mergeTrainIndex: 0, mergeTrainsCount: 0 }, true);

      expect(trimText(wrapper.text())).toBe(
        'A new merge train has started and this merge request is the first of the queue. View merge train details.',
      );
      expect(findLink().attributes('href')).toBe('namespace/project/-/merge_trains');
    });
  });

  describe('with mergeTrainsViz disabled', () => {
    it('should render the correct message', () => {
      createComponent({ mergeTrainIndex: 3 });

      expect(trimText(wrapper.text())).toBe(
        'Added to the merge train. There are 4 merge requests waiting to be merged',
      );
      expect(findLink().exists()).toBe(false);
    });

    it('should change the merge train message when the position is 1', () => {
      createComponent({ mergeTrainIndex: 0 });

      expect(trimText(wrapper.text())).toBe(
        'A new merge train has started and this merge request is the first of the queue.',
      );
      expect(findLink().exists()).toBe(false);
    });
  });
});
