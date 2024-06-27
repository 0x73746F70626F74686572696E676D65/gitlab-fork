import { GlBadge, GlTab, GlTabs } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainTabs from 'ee/ci/merge_trains/components/merge_train_tabs.vue';

describe('MergeTrainTabs', () => {
  let wrapper;

  const defaultProps = {
    activeTrain: {
      cars: {
        count: 5,
      },
    },
    mergedTrain: {
      cars: {
        count: 5,
      },
    },
  };

  const createComponent = (mountFn = mountExtended, props = defaultProps) => {
    wrapper = mountFn(MergeTrainTabs, {
      propsData: {
        ...props,
      },
      stubs: {
        GlTab,
        GlBadge,
      },
    });
  };

  const findTabs = () => wrapper.findComponent(GlTabs);
  const findActiveCarsTab = () => wrapper.findByTestId('active-cars-tab');
  const findMergedCarsTab = () => wrapper.findByTestId('merged-cars-tab');

  it('displays tabs', () => {
    createComponent();

    expect(findTabs().exists()).toBe(true);
  });

  it('displays active tab text and count', () => {
    createComponent(shallowMountExtended);

    expect(findActiveCarsTab().text()).toContain('Active');
    expect(findActiveCarsTab().text()).toContain(`${defaultProps.activeTrain.cars.count}`);
  });

  it('displays merged tab text and count', () => {
    createComponent(shallowMountExtended);

    expect(findMergedCarsTab().text()).toContain('Merged');
    expect(findMergedCarsTab().text()).toContain(`${defaultProps.mergedTrain.cars.count}`);
  });

  it('emits the activeTabClicked event', () => {
    createComponent();

    findActiveCarsTab().vm.$emit('click');

    expect(wrapper.emitted('activeTabClicked')).toEqual([[]]);
  });

  it('emits the mergedTabClicked event', () => {
    createComponent();

    findMergedCarsTab().vm.$emit('click');

    expect(wrapper.emitted('mergedTabClicked')).toEqual([[]]);
  });

  it('passes the `sync-active-tab-with-query-params` prop', () => {
    createComponent();

    expect(findTabs().props('syncActiveTabWithQueryParams')).toBe(true);
  });
});
