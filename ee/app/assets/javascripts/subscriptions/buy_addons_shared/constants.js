import { s__, n__ } from '~/locale';

/* eslint-disable @gitlab/require-i18n-strings */
export const planTags = {
  CI_1000_MINUTES_PLAN: 'CI_1000_MINUTES_PLAN',
  STORAGE_PLAN: 'STORAGE_PLAN',
};
/* eslint-enable @gitlab/require-i18n-strings */
export const CUSTOMER_CLIENT = 'customerClient';
export const GITLAB_CLIENT = 'gitlabClient';

export const CI_MINUTES_PER_PACK = 1000;
export const STORAGE_PER_PACK = 10;

export const I18N_CI_MINUTES_PRODUCT_LABEL = s__('Checkout|CI minute pack');
export const I18N_CI_MINUTES_PRODUCT_UNIT = s__('Checkout|minutes');
export const I18N_CI_MINUTES_FORMULA_TOTAL = s__('Checkout|%{totalCiMinutes} CI minutes');
export const i18nCIMinutesSummaryTitle = (quantity) =>
  n__('Checkout|%d CI minute pack', 'Checkout|%d CI minute packs', quantity);
export const I18N_CI_MINUTES_SUMMARY_TOTAL = s__('Checkout|Total minutes: %{quantity}');
export const I18N_CI_MINUTES_ALERT_TEXT = s__(
  "Checkout|CI minute packs are only used after you've used your subscription's monthly quota. The additional minutes will roll over month to month and are valid for one year.",
);

export const I18N_STORAGE_PRODUCT_LABEL = s__('Checkout|Storage packs');
export const I18N_STORAGE_PRODUCT_UNIT = s__('Checkout|GB');
export const I18N_STORAGE_FORMULA_TOTAL = s__('Checkout|%{quantity} GB of storage');
export const i18nStorageSummaryTitle = (quantity) =>
  n__('Checkout|%{quantity} storage pack', 'Checkout|%{quantity} storage packs', quantity);
export const I18N_STORAGE_SUMMARY_TOTAL = s__('Checkout|Total storage: %{quantity} GB');

export const I18N_DETAILS_STEP_TITLE = s__('Checkout|Purchase details');
export const I18N_DETAILS_NEXT_STEP_BUTTON_TEXT = s__('Checkout|Continue to billing');
export const I18N_DETAILS_FORMULA = s__('Checkout|x %{quantity} %{units} per pack =');
