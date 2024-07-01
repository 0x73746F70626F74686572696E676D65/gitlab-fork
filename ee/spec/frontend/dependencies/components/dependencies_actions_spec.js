import { GlSorting } from '@gitlab/ui';
import { nextTick } from 'vue';
import DependenciesActions from 'ee/dependencies/components/dependencies_actions.vue';
import GroupDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue';
import createStore from 'ee/dependencies/store';
import { DEPENDENCY_LIST_TYPES } from 'ee/dependencies/store/constants';
import {
  SORT_FIELDS_GROUP,
  SORT_FIELDS_PROJECT,
} from 'ee/dependencies/store/modules/list/constants';
import * as urlUtility from '~/lib/utils/url_utility';
import { TEST_HOST } from 'helpers/test_constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('DependenciesActions component', () => {
  let store;
  let wrapper;
  const { namespace } = DEPENDENCY_LIST_TYPES.all;

  const objectBasicProp = {
    namespaceType: 'project',
    belowGroupLimit: true,
  };

  const factory = ({ propsData, provide } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    wrapper = shallowMountExtended(DependenciesActions, {
      store,
      propsData: { ...propsData },
      provide: {
        ...objectBasicProp,
        ...provide,
      },
    });
  };

  const findSorting = () => wrapper.findComponent(GlSorting);
  const emitSortByChange = (value) => findSorting().vm.$emit('sortByChange', value);

  beforeEach(async () => {
    factory({
      propsData: { namespace },
    });
    store.state[namespace].endpoint = `${TEST_HOST}/dependencies.json`;
    jest.spyOn(urlUtility, 'updateHistory');
    await nextTick();
  });

  it('dispatches the right setSortField action on clicking each item in the dropdown', () => {
    Object.keys(SORT_FIELDS_PROJECT).forEach((field) => {
      emitSortByChange(field);
    });

    expect(store.dispatch.mock.calls).toEqual(
      expect.arrayContaining(
        Object.keys(SORT_FIELDS_PROJECT).map((field) => [`${namespace}/setSortField`, field]),
      ),
    );
  });

  describe('with namespaceType set to group', () => {
    beforeEach(async () => {
      factory({
        propsData: { namespace },
        provide: { namespaceType: 'group' },
      });
      store.state[namespace].endpoint = `${TEST_HOST}/dependencies.json`;
      await nextTick();
    });

    it('dispatches the right setSortField action on clicking each item in the dropdown', () => {
      Object.keys(SORT_FIELDS_GROUP).forEach((field) => {
        emitSortByChange(field);
      });

      expect(store.dispatch.mock.calls).toEqual(
        expect.arrayContaining(
          Object.keys(SORT_FIELDS_GROUP).map((field) => [`${namespace}/setSortField`, field]),
        ),
      );
      expect(urlUtility.updateHistory).toHaveBeenCalledTimes(4);
      expect(urlUtility.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/`,
      });
    });

    it('renders a filtered-search input', () => {
      expect(wrapper.findComponent(GroupDependenciesFilteredSearch).exists()).toBe(true);
    });

    describe('with the "belowGroupLimit" set to false', () => {
      beforeEach(async () => {
        factory({
          propsData: { namespace },
          provide: {
            namespaceType: 'group',
            belowGroupLimit: false,
          },
        });
        store.state[namespace].endpoint = `${TEST_HOST}/dependencies.json`;
        await nextTick();
      });

      it('does not dispatch the "license" action', () => {
        findSorting()
          .props('sortOptions')
          .forEach((option) => {
            emitSortByChange(option.value);
          });

        expect(store.dispatch.mock.calls).not.toEqual(
          expect.arrayContaining([[`${namespace}/setSortField`, 'license']]),
        );
      });
    });
  });

  it('dispatches the toggleSortOrder action on clicking the sort order button', () => {
    findSorting().vm.$emit('sortDirectionChange');
    expect(store.dispatch).toHaveBeenCalledWith(`${namespace}/toggleSortOrder`);
    expect(urlUtility.updateHistory).toHaveBeenCalledTimes(1);
    expect(urlUtility.updateHistory).toHaveBeenCalledWith({
      url: `${TEST_HOST}/`,
    });
  });
});
