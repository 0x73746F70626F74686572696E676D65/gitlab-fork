import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainsApp from 'ee/ci/merge_trains/merge_trains_app.vue';
import MergeTrainTabs from 'ee/ci/merge_trains/components/merge_train_tabs.vue';
import MergeTrainsTable from 'ee/ci/merge_trains/components/merge_trains_table.vue';

describe('MergeTrainsApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(MergeTrainsApp, { provide: { fullPath: 'namespace/project' } });
  };

  const findApp = () => wrapper.findComponent(MergeTrainsApp);
  const findTabs = () => wrapper.findComponent(MergeTrainTabs);
  const findTable = () => wrapper.findComponent(MergeTrainsTable);

  it('renders the merge trains app', () => {
    createComponent();

    expect(findApp().exists()).toBe(true);
  });

  it('renders merge train tabs', () => {
    createComponent();

    expect(findTabs().exists()).toBe(true);
  });

  it('renders the merge trains table', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });
});
