import { shallowMount } from '@vue/test-utils';

import {
  GREEN_400,
  BRAND_ORANGE_01,
  BRAND_ORANGE_02,
  BRAND_ORANGE_03,
} from '@gitlab/ui/src/tokens/build/js/tokens';

import CircularProgressBar from 'ee/vue_shared/components/circular_progress_bar/circular_progress_bar.vue';

describe('Learn GitLab', () => {
  let wrapper;

  const createWrapper = (propsData) => {
    wrapper = shallowMount(CircularProgressBar, { propsData });
  };

  describe('Circular Progress Bar', () => {
    it.each`
      percentage | color
      ${1}       | ${BRAND_ORANGE_03}
      ${49}      | ${BRAND_ORANGE_03}
      ${50}      | ${BRAND_ORANGE_02}
      ${51}      | ${BRAND_ORANGE_02}
      ${74}      | ${BRAND_ORANGE_02}
      ${75}      | ${BRAND_ORANGE_01}
      ${76}      | ${BRAND_ORANGE_01}
      ${99}      | ${BRAND_ORANGE_01}
      ${100}     | ${GREEN_400}
    `('renders $color color for $percentage%', ({ percentage, color }) => {
      createWrapper({ percentage });

      expect(wrapper.find('.circular-progress-bar').attributes('style')).toContain(
        `--percentage: ${percentage}%; --progress-bar-color: ${color};`,
      );
    });
  });
});
