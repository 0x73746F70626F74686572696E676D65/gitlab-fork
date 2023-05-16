import { GlButton, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import VisualizationSelector from 'ee/vue_shared/components/customizable_dashboard/dashboard_editor/visualization_selector.vue';
import { humanize } from '~/lib/utils/text_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { builtinVisualizations } from 'ee/analytics/analytics_dashboards/gl_dashboards';

describe('VisualizationSelector', () => {
  let wrapper;

  const dataSource = 'foo';

  const availableVisualizations = (options) => ({
    [dataSource]: {
      loading: false,
      visualizationIds: Object.keys(builtinVisualizations),
      ...options,
    },
  });

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(VisualizationSelector, {
      propsData: {
        availableVisualizations: {},
        ...props,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findListItems = () => wrapper.findAll('li');

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits an "create" event when the button is clicked', async () => {
      await findButton().vm.$emit('click');

      expect(wrapper.emitted('create')).toEqual([[]]);
    });

    it('does not render the data source title', () => {
      expect(wrapper.text()).not.toContain(dataSource);
    });

    it('does not render any list items', () => {
      expect(findListItems()).toHaveLength(0);
    });
  });

  describe('when loading available visualizations', () => {
    beforeEach(() => {
      createWrapper({ availableVisualizations: availableVisualizations({ loading: true }) });
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render any list items', () => {
      expect(findListItems()).toHaveLength(0);
    });
  });

  describe('when created with available visualization', () => {
    beforeEach(() => {
      createWrapper({ availableVisualizations: availableVisualizations() });
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the available data source titles', () => {
      Object.keys(availableVisualizations()).forEach((title) => {
        expect(wrapper.text()).toContain(title);
      });
    });

    it('renders a list item for each available id', () => {
      const ids = Object.values(availableVisualizations())
        .map(({ visualizationIds }) => visualizationIds)
        .flat();

      ids.forEach((id, index) => {
        const item = findListItems().at(index);

        expect(item.text()).toBe(humanize(id));
        expect(item.findComponent(GlIcon).props().name).toBe('chart');
      });
    });

    it.each`
      scenario                         | event
      ${'an item is clicked'}          | ${'click'}
      ${'enter is pressed on an item'} | ${'keydown.enter'}
    `('emits "select" when $scenario', async ({ event }) => {
      const item = findListItems().at(0);

      await item.trigger(event);

      expect(wrapper.emitted('select')).toEqual([
        [availableVisualizations()[dataSource].visualizationIds[0], 'yml'],
      ]);
    });
  });
});
