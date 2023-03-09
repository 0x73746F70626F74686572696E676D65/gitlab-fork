import { mount } from '@vue/test-utils';
import { GlIcon } from '@gitlab/ui';

import TableHeaderComponent from 'ee/analytics/contribution_analytics/legacy_components/table_header.vue';
import { LEGACY_TABLE_COLUMNS } from 'ee/analytics/contribution_analytics/constants';

import { MOCK_SORT_ORDERS } from '../mock_data';

const createComponent = (columns = LEGACY_TABLE_COLUMNS, sortOrders = MOCK_SORT_ORDERS) =>
  mount(TableHeaderComponent, { propsData: { columns, sortOrders } });

describe('TableHeaderComponent', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  const firstColumnName = 'fullname';

  it('renders table column header with sort order icon', () => {
    const firstHeaderItem = wrapper.find('tr th');

    expect(firstHeaderItem.exists()).toBe(true);
    expect(firstHeaderItem.getComponent(GlIcon).props('name')).toBe('chevron-lg-up');
  });

  it('emits `onColumnClick` event with columnName param on component instance when clicked on relevant header', async () => {
    await wrapper.find('th').trigger('click');

    expect(wrapper.emitted('onColumnClick')[0]).toStrictEqual([firstColumnName]);
  });

  it('updates columnIconMeta prop for provided columnName when clicked on relevant header', async () => {
    jest.spyOn(wrapper.vm, 'getColumnIconMeta');

    await wrapper.find('th').trigger('click');

    expect(wrapper.vm.getColumnIconMeta).toHaveBeenCalledWith(firstColumnName, MOCK_SORT_ORDERS);
  });

  it('sorts by first column by default', () => {
    const firstHeaderItem = wrapper.find('tr th');

    expect(firstHeaderItem.find('svg[data-testid="chevron-lg-up-icon"]').exists()).toBe(true);
    expect(firstHeaderItem.attributes('title')).toBe('Ascending');
  });
});
