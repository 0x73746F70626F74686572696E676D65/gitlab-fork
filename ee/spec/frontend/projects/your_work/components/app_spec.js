import { GlTab, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { TEST_HOST } from 'helpers/test_constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import YourWorkProjectsApp from '~/projects/your_work/components/app.vue';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';

jest.mock('~/alert');

describe('YourWorkProjectsApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(YourWorkProjectsApp, {
      stubs: {
        GlSprintf,
        GlTab,
      },
    });
  };

  describe.each`
    path                             | expectedIndex
    ${'/dashboard/projects/removed'} | ${4}
  `('onMount when path is $path', ({ path, expectedIndex }) => {
    useMockLocationHelper();
    beforeEach(async () => {
      delete window.location;
      window.location = new URL(`${TEST_HOST}/${path}`);

      createComponent();
      await nextTick();
    });

    it('initializes to the correct tab', () => {
      expect(wrapper.vm.activeTabIndex).toBe(expectedIndex);
    });
  });
});
