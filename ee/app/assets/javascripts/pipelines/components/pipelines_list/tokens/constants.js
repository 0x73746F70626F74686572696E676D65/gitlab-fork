import { s__ } from '~/locale';
import { PIPELINE_SOURCES as CE_PIPELINE_SOURCES } from '~/pipelines/components/pipelines_list/tokens/constants';

const EE_PIPELINE_SOURCES = [
  {
    text: s__('Pipeline|Source|On-Demand DAST Scan'),
    value: 'ondemand_dast_scan',
  },
  {
    text: s__('Pipeline|Source|On-Demand DAST Validation'),
    value: 'ondemand_dast_validation',
  },
];

export const PIPELINE_SOURCES = [...CE_PIPELINE_SOURCES, ...EE_PIPELINE_SOURCES];
