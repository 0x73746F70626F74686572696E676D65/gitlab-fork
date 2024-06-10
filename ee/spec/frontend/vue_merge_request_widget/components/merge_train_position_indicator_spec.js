import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MergeTrainPositionIndicator from 'ee/vue_merge_request_widget/components/merge_train_position_indicator.vue';
import { STATUS_OPEN, STATUS_MERGED } from '~/issues/constants';
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

    describe.each([0, 1])('when open MR is at %d position', (index) => {
      beforeEach(() => {
        createComponent({ mergeTrainIndex: index, mergeRequestState: STATUS_OPEN });
      });

      it('shows toast when removed from train', async () => {
        expect(mockToast).not.toHaveBeenCalled();

        await wrapper.setProps({ mergeTrainIndex: null, mergeRequestState: STATUS_OPEN });

        expect(mockToast).toHaveBeenCalledTimes(1);
        expect(mockToast).toHaveBeenCalledWith('Merge request was removed from the merge train.');
      });

      it('does not show toast when removed from train due to merge', async () => {
        await wrapper.setProps({ mergeTrainIndex: null, mergeRequestState: STATUS_MERGED });
        expect(mockToast).not.toHaveBeenCalled();
      });
    });

    describe.each([0, 1])('when merged MR is at %d position', (index) => {
      beforeEach(() => {
        createComponent({ mergeTrainIndex: index, mergeRequestState: STATUS_MERGED });
      });

      it('does not show toast when removed from train', async () => {
        await wrapper.setProps({ mergeTrainIndex: null, mergeRequestState: STATUS_MERGED });

        expect(mockToast).not.toHaveBeenCalled();
      });
    });

    describe.each([0, 1])('when open MR is not in train', (newIndex) => {
      beforeEach(() => {
        createComponent({ mergeTrainIndex: null, mergeRequestState: STATUS_OPEN });
      });

      it(`does not show toast when added to train at ${newIndex} position`, async () => {
        await wrapper.setProps({ mergeTrainIndex: newIndex, mergeRequestState: STATUS_OPEN });

        expect(mockToast).not.toHaveBeenCalled();
      });
    });
  });
});
