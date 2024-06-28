import { GlBadge, GlButton } from '@gitlab/ui';
import TracingHeader from 'ee/tracing/details/tracing_header.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('TracingHeader', () => {
  let wrapper;

  const defaultTrace = {
    service_name: 'Service',
    operation: 'Operation',
    timestamp: 1692021937219,
    duration_nano: 1000000000,
    total_spans: 10,
    spans: [
      { span_id: 'span-1', parent_span_id: '' },
      { span_id: 'span-2', parent_span_id: 'span-1' },
    ],
  };

  const createComponent = (trace = defaultTrace, incomplete = false) => {
    wrapper = shallowMountExtended(TracingHeader, {
      propsData: {
        trace,
        incomplete,
        logsLink: 'testLogsLink',
      },
    });
  };
  beforeEach(() => {
    createComponent();
  });

  const findHeading = () => wrapper.findComponent(PageHeading);

  it('renders the correct title', () => {
    expect(findHeading().text()).toContain('Service : Operation');
  });

  it('does not show the in progress label if incomplete=false', () => {
    expect(findHeading().findComponent(GlBadge).exists()).toBe(false);

    expect(findHeading().text()).not.toContain('In progress');
  });

  it('shows the in progress label when incomplete=true', () => {
    createComponent(
      {
        ...defaultTrace,
      },
      true,
    );

    expect(findHeading().findComponent(GlBadge).exists()).toBe(true);
    expect(findHeading().text()).toContain('In progress');
  });

  it('renders the correct logs link', () => {
    const button = findHeading().findComponent(GlButton);
    expect(button.text()).toBe('View Logs');
    expect(button.attributes('href')).toBe('testLogsLink');
  });

  it('renders the correct trace date', () => {
    expect(wrapper.findByTestId('trace-date-card').text()).toMatchInterpolatedText(
      'Trace start Aug 14, 2023 14:05:37.219 UTC',
    );
  });

  it('renders the correct trace duration', () => {
    expect(wrapper.findByTestId('trace-duration-card').text()).toMatchInterpolatedText(
      'Duration 1s',
    );
  });

  it('renders the correct total spans', () => {
    expect(wrapper.findByTestId('trace-spans-card').text()).toMatchInterpolatedText(
      'Total spans 10',
    );
  });
});
