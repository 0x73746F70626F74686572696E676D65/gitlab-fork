import { GlLoadingIcon } from '@gitlab/ui';
import ObservabilityUsageQuota from 'ee/usage_quotas/observability/components/observability_usage_quota.vue';
import ObservabilityUsageBreakdown from 'ee/usage_quotas/observability/components/observability_usage_breakdown.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

jest.mock('~/alert');

describe('ObservabilityUsageQuota', () => {
  let wrapper;
  let observabilityClientMock;

  const mockUsageData = {
    events: {},
    storage: {},
  };
  const mountComponent = async () => {
    wrapper = shallowMountExtended(ObservabilityUsageQuota, {
      propsData: {
        observabilityClient: observabilityClientMock,
      },
    });
    await waitForPromises();
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findUsageBreakdown = () => wrapper.findComponent(ObservabilityUsageBreakdown);

  beforeEach(() => {
    observabilityClientMock = createMockClient();
    observabilityClientMock.fetchUsageData.mockResolvedValue(mockUsageData);
  });

  it('renders the loading indicator while fetching data', () => {
    mountComponent();

    expect(findLoadingIcon().exists()).toBe(true);
    expect(findUsageBreakdown().exists()).toBe(false);
    expect(observabilityClientMock.fetchUsageData).toHaveBeenCalled();
  });

  it('renders the usage breakdown after fetching data', async () => {
    await mountComponent();

    expect(findLoadingIcon().exists()).toBe(false);
    expect(findUsageBreakdown().exists()).toBe(true);
    expect(findUsageBreakdown().props('usageData')).toEqual(mockUsageData);
  });

  it('if fetchUsageData fails, it renders an alert', async () => {
    observabilityClientMock.fetchUsageData.mockRejectedValue('error');

    await mountComponent();

    expect(createAlert).toHaveBeenLastCalledWith({
      message: 'Failed to load observability usage data.',
    });
    expect(findUsageBreakdown().exists()).toBe(false);
    expect(findLoadingIcon().exists()).toBe(false);
  });
});
