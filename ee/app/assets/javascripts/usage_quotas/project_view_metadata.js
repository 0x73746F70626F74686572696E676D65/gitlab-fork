import { PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';
import { getStorageTabMetadata } from '~/usage_quotas/storage/tab_metadata';
import { getTransferTabMetadata } from './transfer/tab_metadata';
import { getObservabilityTabMetadata } from './observability/tab_metadata';

export const usageQuotasTabsMetadata = [
  getStorageTabMetadata({ viewType: PROJECT_VIEW_TYPE }),
  getTransferTabMetadata({ viewType: PROJECT_VIEW_TYPE }),
  getObservabilityTabMetadata(),
].filter(Boolean);
