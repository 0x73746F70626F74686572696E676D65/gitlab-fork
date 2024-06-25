import { GlFormSelect } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AnalyticsVisualizationTypeSelector from 'ee/analytics/analytics_dashboards/components/visualization_designer/analytics_visualization_type_selector.vue';

describe('AnalyticsVisualizationTypeSelector', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createWrapper = (value = '', state = null) => {
    wrapper = shallowMountExtended(AnalyticsVisualizationTypeSelector, {
      propsData: {
        value,
        state,
      },
    });
  };

  const findSelect = () => wrapper.findComponent(GlFormSelect);

  it.each`
    value
    ${'LineChart'}
    ${'ColumnChart'}
    ${'DataTable'}
    ${'SingleStat'}
  `('renders select with expected attributes for "$value"', ({ value }) => {
    createWrapper(value, true);

    expect(findSelect().attributes('value')).toEqual(value);
    expect(findSelect().attributes('state')).toEqual('true');
  });

  it('emits selected value on input', () => {
    createWrapper();

    findSelect().vm.$emit('input', 'LineChart');

    expect(wrapper.emitted('input')).toHaveLength(1);
    expect(wrapper.emitted('input').at(0)).toEqual(['LineChart']);
  });
});
