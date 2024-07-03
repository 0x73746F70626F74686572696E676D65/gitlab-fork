import { GlBanner } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MergeTrainsFeedbackBanner from 'ee/ci/merge_trains/components/merge_trains_feedback_banner.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

describe('MergeTrainsFeedbackBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(MergeTrainsFeedbackBanner);
  };

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  beforeEach(() => {
    createComponent();
  });

  it('renders the feedback banner', () => {
    expect(findBanner().props()).toMatchObject({
      title: 'Tell us what you think',
      buttonText: 'Give feedback',
      buttonLink: 'https://gitlab.com/gitlab-org/gitlab/-/issues/464774',
    });
  });

  it('sets localStorage storageKey to the expected key', () => {
    expect(findLocalStorageSync().props('storageKey')).toBe('merge_trains_viz_feedback_banner');
  });

  it('uses localStorage with default value as false', () => {
    expect(findLocalStorageSync().props('value')).toBe(false);
  });

  describe('when the banner is dimsissed', () => {
    beforeEach(() => {
      findBanner().vm.$emit('close');
    });

    it('hides the banner', () => {
      expect(findBanner().exists()).toBe(false);
    });

    it('updates localStorage value to true', () => {
      expect(findLocalStorageSync().props('value')).toBe(true);
    });
  });
});
