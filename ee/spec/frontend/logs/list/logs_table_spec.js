import { GlTable, GlLabel } from '@gitlab/ui';
import { nextTick } from 'vue';
import LogsTable from 'ee/logs/list/logs_table.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { mockLogs } from './mock_data';

describe('LogsTable', () => {
  let wrapper;

  const mountComponent = ({ logs = mockLogs } = {}) => {
    wrapper = mountExtended(LogsTable, {
      propsData: {
        logs,
      },
    });
  };

  const getRows = () => wrapper.findComponent(GlTable).findAll(`[data-testid="log-row"]`);
  const getRow = (idx) => getRows().at(idx);
  const clickRow = async (idx) => {
    getRow(idx).trigger('click');
    await nextTick();
  };

  it('renders logs as table', () => {
    mountComponent();

    const rows = getRows();
    expect(rows.length).toBe(mockLogs.length);
    mockLogs.forEach((m, i) => {
      const row = getRows().at(i);
      expect(row.find(`[data-testid="log-timestamp"]`).text()).toBe(formatDate(m.timestamp));
      expect(row.find(`[data-testid="log-service"]`).text()).toBe(m.service_name);
      expect(row.find(`[data-testid="log-message"]`).text()).toBe(m.body);
    });
  });

  describe('label', () => {
    it.each([
      [1, 'trace', '#a4a3a8'],
      [2, 'trace2', '#a4a3a8'],
      [3, 'trace3', '#a4a3a8'],
      [4, 'trace4', '#a4a3a8'],
      [5, 'debug', '#a4a3a8'],
      [6, 'debug2', '#a4a3a8'],
      [7, 'debug3', '#a4a3a8'],
      [8, 'debug4', '#a4a3a8'],
      [9, 'info', '#428fdc'],
      [10, 'info2', '#428fdc'],
      [11, 'info3', '#428fdc'],
      [12, 'info4', '#428fdc'],
      [13, 'warn', '#e9be74'],
      [14, 'warn2', '#e9be74'],
      [15, 'warn3', '#e9be74'],
      [16, 'warn4', '#e9be74'],
      [17, 'error', '#dd2b0e'],
      [18, 'error2', '#dd2b0e'],
      [19, 'error3', '#dd2b0e'],
      [20, 'error4', '#dd2b0e'],
      [21, 'fatal', '#dd2b0e'],
      [22, 'fatal2', '#dd2b0e'],
      [23, 'fatal3', '#dd2b0e'],
      [24, 'fatal4', '#dd2b0e'],
      [100, 'debug', '#a4a3a8'],
      [0, 'debug', '#a4a3a8'],
    ])('sets the proper label when log severity is %d', (severity, title, color) => {
      mountComponent({
        logs: [{ severity_number: severity }],
      });
      const label = wrapper.findComponent(GlLabel);
      expect(label.props('backgroundColor')).toBe(color);
      expect(label.props('title')).toBe(title);
    });
  });

  it('emits log-selected on row-clicked', async () => {
    mountComponent();

    await clickRow(0);
    expect(wrapper.emitted('log-selected')[0]).toEqual([{ fingerprint: mockLogs[0].fingerprint }]);
  });
});
