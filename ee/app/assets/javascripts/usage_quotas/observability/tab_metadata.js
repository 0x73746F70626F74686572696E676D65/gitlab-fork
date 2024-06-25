import { s__ } from '~/locale';
import { OBSERVABILITY_TAB_METADATA_EL_SELECTOR } from '../constants';
import ObservabilityUsageQuotaApp from './components/observability_usage_quota_app.vue';

export const parseProvideData = (element) => {
  return element.dataset.viewModel ? JSON.parse(element.dataset.viewModel) : {};
};

export const getObservabilityTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector(OBSERVABILITY_TAB_METADATA_EL_SELECTOR);

  if (!el) return false;

  const observabilityTabMetadata = {
    title: s__('UsageQuota|Observability'),
    hash: '#observability-usage-quota-tab',
    testid: 'observability-tab',
    component: {
      name: 'ObservabilityUsageQuotaTab',
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(ObservabilityUsageQuotaApp);
      },
    },
  };

  if (includeEl) {
    observabilityTabMetadata.component.el = el;
  }

  return observabilityTabMetadata;
};
