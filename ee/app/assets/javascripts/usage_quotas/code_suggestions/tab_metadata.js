import { s__ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from '../shared/provider';
import { CODE_SUGGESTIONS_TAB_METADATA_EL_SELECTOR } from '../constants';
import CodeSuggestionsUsage from './components/code_suggestions_usage.vue';

export const parseProvideData = (el) => {
  const {
    fullPath,
    groupId,
    firstName,
    lastName,
    companyName,
    namespaceId,
    buttonAttributes,
    createHandRaiseLeadPath,
    glmContent,
    productInteraction,
    trackAction,
    trackLabel,
    userName,
    addDuoProHref,
    duoProBulkUserAssignmentAvailable,
  } = el.dataset;

  return {
    fullPath,
    groupId,
    createHandRaiseLeadPath,
    addDuoProHref,
    isSaaS: true,
    isBulkAddOnAssignmentEnabled: parseBoolean(duoProBulkUserAssignmentAvailable),
    buttonAttributes: buttonAttributes && { ...JSON.parse(buttonAttributes), variant: 'confirm' },
    user: {
      namespaceId,
      userName,
      firstName,
      lastName,
      companyName,
    },
    glmContent,
    productInteraction,
    ctaTracking: {
      action: trackAction,
      label: trackLabel,
    },
  };
};

export const getCodeSuggestionsTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector(CODE_SUGGESTIONS_TAB_METADATA_EL_SELECTOR);

  if (!el) return false;

  const codeSuggestionsTabMetadata = {
    title: s__('UsageQuota|GitLab Duo Pro'),
    hash: '#code-suggestions-usage-tab',
    testid: 'code-suggestions-tab',
    component: {
      name: 'CodeSuggestionsUsageTab',
      apolloProvider,
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(CodeSuggestionsUsage);
      },
    },
  };

  if (includeEl) {
    codeSuggestionsTabMetadata.component.el = el;
  }

  return codeSuggestionsTabMetadata;
};
