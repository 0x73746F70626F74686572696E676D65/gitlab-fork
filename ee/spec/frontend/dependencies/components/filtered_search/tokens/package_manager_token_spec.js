import { nextTick } from 'vue';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlIntersperse,
  GlLoadingIcon,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PackageManagerToken from 'ee/dependencies/components/filtered_search/tokens/package_manager_token.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { trimText } from 'helpers/text_helper';
import { stubComponent } from 'helpers/stub_component';

const TEST_PACKAGE_MANAGERS = [
  { id: 'gid://gitlab/Packager/1', name: 'bundler' },
  { id: 'gid://gitlab/Packager/2', name: 'npm' },
  { id: 'gid://gitlab/Packager/3', name: 'crate' },
];

describe('ee/dependencies/components/filtered_search/tokens/package_manager_token.vue', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PackageManagerToken, {
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
        ...propsData,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
        GlIntersperse,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findAllFilteredSearchSuggestions = () =>
    wrapper.findAllComponents(GlFilteredSearchSuggestion);

  const isLoadingSuggestions = () => wrapper.findComponent(GlLoadingIcon).exists();
  const searchForPackageManager = (searchTerm = '') => {
    findFilteredSearchToken().vm.$emit('input', { data: searchTerm });
    return waitForPromises();
  };
  const selectPackageManager = (packageManager) => {
    findFilteredSearchToken().vm.$emit('select', packageManager);
    return nextTick();
  };

  describe('when the component is initially rendered', () => {
    it('shows a loading indicator while fetching the list of package managers', () => {
      createComponent();

      expect(isLoadingSuggestions()).toBe(true);
    });
  });

  describe('when the package managers are fetched', () => {
    beforeEach(() => {
      createComponent();
      waitForPromises();
    });

    it('does not show a loading indicator', () => {
      expect(isLoadingSuggestions()).toBe(false);
    });

    describe('when a user enters a search term', () => {
      const findAllPackages = () => {
        const packages = [];
        const elements = findAllFilteredSearchSuggestions().wrappers;

        for (const el of elements) {
          packages.push(el.props('value'));
        }

        return packages;
      };

      it('shows the filtered list of suggestions', async () => {
        expect(findAllPackages()).toEqual(TEST_PACKAGE_MANAGERS);

        await searchForPackageManager(TEST_PACKAGE_MANAGERS[0].name);

        expect(findAllPackages()).toEqual([TEST_PACKAGE_MANAGERS[0]]);
      });
    });

    describe('when a user selects package managers', () => {
      it('displays a check-icon next to the selected package manager', async () => {
        const findFirstSearchSuggestionIcon = () =>
          findAllFilteredSearchSuggestions().at(0).findComponent(GlIcon);
        const hiddenClassName = 'gl-invisible';

        expect(findFirstSearchSuggestionIcon().classes()).toContain(hiddenClassName);

        await selectPackageManager(TEST_PACKAGE_MANAGERS[0]);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain(hiddenClassName);
      });

      it('shows a comma seperated list of the selected package managers', async () => {
        await selectPackageManager(TEST_PACKAGE_MANAGERS[0]);
        await selectPackageManager(TEST_PACKAGE_MANAGERS[1]);

        expect(trimText(wrapper.findByTestId('selected-package-managers').text())).toBe(
          `${TEST_PACKAGE_MANAGERS[0].name}, ${TEST_PACKAGE_MANAGERS[1].name}`,
        );
      });
    });
  });
});
