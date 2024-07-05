import ObservabilityUsageQuotaApp from 'ee/usage_quotas/observability/components/observability_usage_quota_app.vue';
import ObservabilityUsageQuota from 'ee/usage_quotas/observability/components/observability_usage_quota.vue';
import ProvisionedObservabilityContainer from '~/observability/components/provisioned_observability_container.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ObservabilityUsageQuotaApp', () => {
  let wrapper;

  const apiConfig = {
    oauthUrl: 'https://example.com/oauth',
    tracingUrl: 'https://example.com/tracing',
    provisioningUrl: 'https://example.com/provisioning',
    servicesUrl: 'https://example.com/services',
    operationsUrl: 'https://example.com/operations',
    metricsUrl: 'https://example.com/metricsUrl',
    analyticsUrl: 'https://example.com/analyticsUrl',
  };

  const mountComponent = () => {
    wrapper = shallowMountExtended(ObservabilityUsageQuotaApp, {
      provide: {
        apiConfig,
      },
    });
  };

  it('renders provisioned-observability-container component', () => {
    mountComponent();

    const observabilityContainer = wrapper.findComponent(ProvisionedObservabilityContainer);
    expect(observabilityContainer.exists()).toBe(true);
    expect(observabilityContainer.props('apiConfig')).toStrictEqual(apiConfig);
  });

  it('renders the ObservabilityUsageQuota', () => {
    mountComponent();

    expect(wrapper.findComponent(ObservabilityUsageQuota).exists()).toBe(true);
  });
});
