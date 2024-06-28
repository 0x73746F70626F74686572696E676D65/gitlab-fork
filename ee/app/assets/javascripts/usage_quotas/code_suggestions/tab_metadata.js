import { s__ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from '../shared/provider';
import { CODE_SUGGESTIONS_TAB_METADATA_EL_SELECTOR } from '../constants';
import CodeSuggestionsUsage from './components/code_suggestions_usage.vue';

export const parseProvideData = (el) => {
  const {
    fullPath,
    groupId,
    duoProTrialHref,
    addDuoProHref,
    duoProBulkUserAssignmentAvailable,
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    handRaiseLeadGlmContent,
    handRaiseLeadProductInteraction,
    handRaiseLeadButtonAttributes,
    handRaiseLeadCtaTracking,
  } = el.dataset;

  let handRaiseLeadButtonAttributesParsed;
  let handRaiseLeadCtaTrackingParsed;

  try {
    handRaiseLeadButtonAttributesParsed = JSON.parse(handRaiseLeadButtonAttributes);
  } catch {
    handRaiseLeadButtonAttributesParsed = {};
  }

  try {
    handRaiseLeadCtaTrackingParsed = JSON.parse(handRaiseLeadCtaTracking);
  } catch {
    handRaiseLeadCtaTrackingParsed = {};
  }

  return {
    fullPath,
    groupId,
    duoProTrialHref,
    addDuoProHref,
    isSaaS: true,
    isBulkAddOnAssignmentEnabled: parseBoolean(duoProBulkUserAssignmentAvailable),
    subscriptionName,
    subscriptionStartDate,
    subscriptionEndDate,
    handRaiseLeadData: {
      glmContent: handRaiseLeadGlmContent,
      productInteraction: handRaiseLeadProductInteraction,
      buttonAttributes: handRaiseLeadButtonAttributesParsed,
      ctaTracking: handRaiseLeadCtaTrackingParsed,
    },
  };
};

export const getCodeSuggestionsTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector(CODE_SUGGESTIONS_TAB_METADATA_EL_SELECTOR);

  if (!el) return false;

  const codeSuggestionsTabMetadata = {
    title: s__('UsageQuota|GitLab Duo'),
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
