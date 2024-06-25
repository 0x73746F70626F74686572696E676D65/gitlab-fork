import { GlDrawer, GlLink } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LogsDrawer from 'ee/logs/list/logs_drawer.vue';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

jest.mock('~/lib/utils/dom_utils');

describe('LogsDrawer', () => {
  let wrapper;

  const findDrawer = () => wrapper.findComponent(GlDrawer);

  const mockLog = {
    fingerprint: 'log-1',
    body: 'GetCartAsync called with userId={userId}',
    service_name: 'a/service/name',
    log_id: 'log-id',
    severity_text: 'Information',
    severity_number: 1,
    trace_flags: 1,
    timestamp: '2024-01-28T10:36:08.2960655Z',
    trace_id: 'trace-id',
    resource_attributes: {
      'container.id': '8aae63236c224245383acd38611a4e32d09b7630573421fcc801918eda378bf5',
      'k8s.deployment.name': 'otel-demo-cartservice',
    },
    log_attributes: {
      userId: 'user-id',
    },
  };

  const testTracingIndexUrl = 'https://tracing-index-url.com';

  const mountComponent = ({ open = true, log = mockLog } = {}) => {
    wrapper = shallowMountExtended(LogsDrawer, {
      propsData: {
        log,
        open,
        tracingIndexUrl: testTracingIndexUrl,
      },
    });
  };

  const findSection = (sectionId) => {
    const section = wrapper.findByTestId(sectionId);
    const title = section.find('[data-testid="section-title"]').text();
    const lines = section.findAll('[data-testid="section-line"]').wrappers.map((w) => ({
      name: w.find('[data-testid="section-line-name"]').text(),
      value: w.find('[data-testid="section-line-value"]').text(),
    }));
    return {
      title,
      lines,
    };
  };

  const getSectionLineWrapperByName = (name) =>
    wrapper
      .findByTestId('section-log-details')
      .findAll('[data-testid="section-line"]')
      .wrappers.find((w) => w.find('[data-testid="section-line-name"]').text() === name);

  beforeEach(() => {
    mountComponent();
  });

  it('renders the component properly', () => {
    expect(wrapper.exists()).toBe(true);
    expect(findDrawer().exists()).toBe(true);
    expect(findDrawer().props('open')).toBe(true);
  });

  it('emits close', () => {
    findDrawer().vm.$emit('close');
    expect(wrapper.emitted('close').length).toBe(1);
  });

  it('displays the correct title', () => {
    expect(wrapper.findByTestId('drawer-title').text()).toBe('2024-01-28T10:36:08Z');
  });

  it.each([
    [
      'section-log-details',
      'Metadata',
      [
        { name: 'body', value: 'GetCartAsync called with userId={userId}' },
        { name: 'fingerprint', value: 'log-1' },
        { name: 'log_id', value: 'log-id' },
        { name: 'service_name', value: 'a/service/name' },
        { name: 'severity_number', value: '1' },
        { name: 'severity_text', value: 'Information' },
        { name: 'timestamp', value: '2024-01-28T10:36:08.2960655Z' },
        { name: 'trace_flags', value: '1' },
        { name: 'trace_id', value: 'trace-id' },
      ],
    ],
    [
      'section-log-attributes',
      'Attributes',
      [
        {
          name: 'userId',
          value: 'user-id',
        },
      ],
    ],
    [
      'section-resource-attributes',
      'Resource attributes',
      [
        {
          name: 'container.id',
          value: '8aae63236c224245383acd38611a4e32d09b7630573421fcc801918eda378bf5',
        },
        { name: 'k8s.deployment.name', value: 'otel-demo-cartservice' },
      ],
    ],
  ])('displays the %s section in expected order', (sectionId, expectedTitle, expectedLines) => {
    const { title, lines } = findSection(sectionId);
    expect(title).toBe(expectedTitle);
    expect(lines).toEqual(expectedLines);
  });

  it.each([
    ['log_attributes', 'section-log-attributes'],
    ['resource_attributes', 'section-resource-attributes'],
  ])('if %s is missing, it does not render %s', (attrKey, sectionId) => {
    mountComponent({ log: { ...mockLog, [attrKey]: undefined } });
    expect(wrapper.findByTestId(sectionId).exists()).toBe(false);
  });

  it('renders a link to the trace', () => {
    const traceLine = getSectionLineWrapperByName('trace_id');
    expect(traceLine.findComponent(GlLink).exists()).toBe(true);
    expect(traceLine.findComponent(GlLink).attributes('href')).toBe(
      `${testTracingIndexUrl}/trace-id`,
    );
  });

  describe('with no log', () => {
    beforeEach(() => {
      mountComponent({ log: null });
    });

    it('displays an empty title', () => {
      expect(wrapper.findByTestId('drawer-title').text()).toBe('');
    });

    it('does not render any section', () => {
      expect(wrapper.findByTestId('section-log-details').exists()).toBe(false);
      expect(wrapper.findByTestId('section-log-attributes').exists()).toBe(false);
      expect(wrapper.findByTestId('section-resource-attributes').exists()).toBe(false);
    });
  });

  describe('header height', () => {
    beforeEach(() => {
      getContentWrapperHeight.mockClear();
      getContentWrapperHeight.mockReturnValue(`1234px`);
    });

    it('does not set the header height if not open', () => {
      mountComponent({ open: false });

      expect(findDrawer().props('headerHeight')).toBe('0');
      expect(getContentWrapperHeight).not.toHaveBeenCalled();
    });

    it('sets the header height to match contentWrapperHeight if open', async () => {
      mountComponent({ open: true });
      await nextTick();

      expect(findDrawer().props('headerHeight')).toBe('1234px');
      expect(getContentWrapperHeight).toHaveBeenCalled();
    });
  });
});
