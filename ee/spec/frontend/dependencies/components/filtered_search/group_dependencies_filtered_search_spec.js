import { shallowMount } from '@vue/test-utils';
import { GlFilteredSearch, GlPopover, GlSprintf } from '@gitlab/ui';
import GroupDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue';
import LicenseToken from 'ee/dependencies/components/filtered_search/tokens/license_token.vue';
import ProjectToken from 'ee/dependencies/components/filtered_search/tokens/project_token.vue';
import PackagerToken from 'ee/dependencies/components/filtered_search/tokens/package_manager_token.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import createStore from 'ee/dependencies/store';

describe('GroupDependenciesFilteredSearch', () => {
  let wrapper;
  let store;

  const createVuexStore = () => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = (mountOptions = {}) => {
    wrapper = shallowMount(GroupDependenciesFilteredSearch, {
      store,
      provide: {
        belowGroupLimit: true,
        glFeatures: {
          groupLevelDependenciesFilteringByComponent: true,
          groupLevelDependenciesFilteringByPackager: true,
        },
      },
      stubs: {
        GlSprintf,
      },
      ...mountOptions,
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findPopover = () => wrapper.findComponent(GlPopover);

  beforeEach(createVuexStore);

  describe('when sub-group limit-count is not reached', () => {
    beforeEach(createComponent);

    it('does not not set the filtered-search to be view-only', () => {
      expect(findFilteredSearch().props('viewOnly')).toBe(false);
    });

    it('does not show a popover', () => {
      expect(findPopover().exists()).toBe(false);
    });

    describe('search input', () => {
      it('displays the correct placeholder', () => {
        expect(findFilteredSearch().props('placeholder')).toBe('Search or filter dependencies...');
      });

      it.each`
        tokenTitle     | tokenConfig
        ${'License'}   | ${{ title: 'License', type: 'licenses', multiSelect: true, token: LicenseToken }}
        ${'Project'}   | ${{ title: 'Project', type: 'project_ids', multiSelect: true, token: ProjectToken }}
        ${'Packager'}  | ${{ title: 'Packager', type: 'package_managers', multiSelect: true, token: PackagerToken }}
        ${'Component'} | ${{ title: 'Component', type: 'component_names', multiSelect: true, token: ComponentToken }}
      `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
        expect(findFilteredSearch().props('availableTokens')).toMatchObject(
          expect.arrayContaining([
            expect.objectContaining({
              ...tokenConfig,
            }),
          ]),
        );
      });
    });

    describe('submit', () => {
      it('dispatches the "fetchDependencies" Vuex action and resets the pagination', () => {
        expect(store.dispatch).not.toHaveBeenCalled();

        const filterPayload = [{ type: 'license', value: { data: ['MIT'] } }];
        findFilteredSearch().vm.$emit('submit', filterPayload);

        expect(store.dispatch).toHaveBeenCalledWith('allDependencies/fetchDependencies', {
          page: 1,
        });
      });
    });
  });

  describe('when group_leven_dependencies_filtering_by_packager feature flag is disabled', () => {
    it('does not contain a "Packager" search token when the feature flag is not enabled', () => {
      createComponent({
        provide: {
          belowGroupLimit: true,
          glFeatures: { groupLevelDependenciesFilteringByPackager: false },
        },
      });

      expect(findFilteredSearch().props('availableTokens')).not.toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            title: 'Packager',
            type: 'package_managers',
            multiSelect: true,
            token: PackagerToken,
          }),
        ]),
      );
    });
  });

  describe('when sub-group limit-count is reached', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          belowGroupLimit: false,
        },
      });
    });

    it('sets the filtered-search to be view-only', () => {
      expect(findFilteredSearch().props('viewOnly')).toBe(true);
    });

    it('when hovering over the filtered-search it shows a popover', () => {
      expect(findFilteredSearch().attributes('id')).toBe('group-level-filtered-search');
      expect(findPopover().props()).toMatchObject({
        target: 'group-level-filtered-search',
      });
    });

    it('shows the correct message in the popover', () => {
      expect(findPopover().props('title')).toBe('Filtering unavailable');
      expect(findPopover().text()).toContain(
        "This group exceeds the maximum number of 600 sub-groups. We cannot accurately filter or search the dependency list above this maximum. To view or filter a subset of this information, go to a subgroup's dependency list.",
      );
    });
  });

  describe('with "groupLevelDependenciesFilteringByComponent" feature flag disabled', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          belowGroupLimit: true,
          glFeatures: { groupLevelDependenciesFilteringByComponent: false },
        },
      });
    });

    it('does not show the Component token', () => {
      expect(findFilteredSearch().props('availableTokens')).not.toContainEqual(
        expect.objectContaining({
          title: 'Component',
        }),
      );
    });
  });
});
