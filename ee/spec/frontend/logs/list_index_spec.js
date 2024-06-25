import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListIndex from 'ee/logs/list_index.vue';
import LogsList from 'ee/logs/list/logs_list.vue';
import ProvisionedObservabilityContainer from '~/observability/components/provisioned_observability_container.vue';

describe('ListIndex', () => {
  const props = {
    apiConfig: {
      oauthUrl: 'https://example.com/oauth',
      tracingUrl: 'https://example.com/tracing',
      provisioningUrl: 'https://example.com/provisioning',
      servicesUrl: 'https://example.com/services',
      operationsUrl: 'https://example.com/operations',
      metricsUrl: 'https://example.com/metricsUrl',
    },
    tracingIndexUrl: 'https://example.com/tracing/index',
  };

  let wrapper;

  const mountComponent = () => {
    wrapper = shallowMountExtended(ListIndex, {
      propsData: props,
    });
  };

  it('renders provisioned-observability-container component', () => {
    mountComponent();

    const observabilityContainer = wrapper.findComponent(ProvisionedObservabilityContainer);
    expect(observabilityContainer.exists()).toBe(true);
    expect(observabilityContainer.props('apiConfig')).toStrictEqual(props.apiConfig);
  });

  it('renders the logs list', () => {
    mountComponent();

    const list = wrapper.findComponent(LogsList);
    expect(list.exists()).toBe(true);
    expect(list.props('tracingIndexUrl')).toBe(props.tracingIndexUrl);
  });
});
