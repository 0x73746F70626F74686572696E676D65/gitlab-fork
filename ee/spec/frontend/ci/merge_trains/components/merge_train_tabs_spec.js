import { GlTabs } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainTabs from 'ee/ci/merge_trains/components/merge_train_tabs.vue';

describe('MergeTrainTabs', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(MergeTrainTabs);
  };

  const findTabs = () => wrapper.findComponent(GlTabs);
  const findActiveTrainsTab = () => wrapper.findByTestId('active-trains-tab');
  const findMergedTrainsTab = () => wrapper.findByTestId('merged-trains-tab');

  it('renders tabs', () => {
    createComponent();

    expect(findTabs().exists()).toBe(true);
  });

  it('emits the activeTabClicked event', () => {
    createComponent();

    findActiveTrainsTab().vm.$emit('click');

    expect(wrapper.emitted('activeTabClicked')).toEqual([[]]);
  });

  it('emits the mergedTabClicked event', () => {
    createComponent();

    findMergedTrainsTab().vm.$emit('click');

    expect(wrapper.emitted('mergedTabClicked')).toEqual([[]]);
  });
});
