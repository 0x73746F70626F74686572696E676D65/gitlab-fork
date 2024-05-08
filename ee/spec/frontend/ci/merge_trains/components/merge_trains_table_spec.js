import { GlTableLite } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainsTable from 'ee/ci/merge_trains/components/merge_trains_table.vue';

describe('MergeTrainsTable', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(MergeTrainsTable);
  };

  const findTable = () => wrapper.findComponent(GlTableLite);

  it('renders table', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });
});
