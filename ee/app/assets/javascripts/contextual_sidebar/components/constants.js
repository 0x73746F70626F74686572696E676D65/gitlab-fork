import { s__ } from '~/locale';

const ACTIVE_TRIAL_POPOVER = 'trial_status_popover';
const TRIAL_ENDED_POPOVER = 'trial_ended_popover';
const CLICK_BUTTON_ACTION = 'click_button';

export const RESIZE_EVENT_DEBOUNCE_MS = 150;
export const RESIZE_EVENT = 'resize';
export const POPOVER_HIDE_DELAY = 400;

export const DUO_PRO_TRIAL_WIDGET_TITLE = s__('DuoProTrial|GitLab Duo Pro Trial');
export const DUO_PRO_TRIAL_WIDGET_DAYS_TEXT = s__('DuoProTrial|Day %{daysUsed}/%{duration}');

export const WIDGET = {
  i18n: {
    widgetTitle: s__('Trials|%{planName} Trial'),
    widgetRemainingDays: s__('Trials|Day %{daysUsed}/%{duration}'),
    widgetTitleExpiredTrial: s__('Trials|Your 30-day trial has ended'),
    widgetBodyExpiredTrial: s__('Trials|Looking to do more with GitLab?'),
    learnAboutButtonTitle: s__('Trials|Learn about features'),
  },
  trackingEvents: {
    action: 'click_link',
    activeTrialOptions: {
      category: 'trial_status_widget',
      label: 'ultimate_trial',
    },
    trialEndedOptions: {
      category: 'trial_ended_widget',
      label: 'your_30_day_trial_has_ended',
    },
  },
};

export const POPOVER = {
  i18n: {
    close: s__('Modal|Close'),
    compareAllButtonTitle: s__('Trials|Compare all plans'),
    popoverContent: s__(`Trials|Your trial ends on
      %{boldStart}%{trialEndDate}%{boldEnd}. We hope you’re enjoying the
      features of GitLab %{planName}. To keep those features after your trial
      ends, you’ll need to buy a subscription. (You can also choose GitLab
      Premium if it meets your needs.)`),
    popoverTitleExpiredTrial: s__("Trials|Don't lose out on additional GitLab features"),
    popoverContentExpiredTrial: s__(
      'Trials|Upgrade to regain access to powerful features like advanced team management for code, security, and reporting.',
    ),
    learnAboutButtonTitle: s__('Trials|Learn about features'),
  },
  trackingEvents: {
    activeTrialCategory: ACTIVE_TRIAL_POPOVER,
    trialEndedCategory: TRIAL_ENDED_POPOVER,
    popoverShown: { action: 'render_popover' },
    contactSalesBtnClick: {
      action: CLICK_BUTTON_ACTION,
      label: 'contact_sales',
    },
    compareBtnClick: {
      action: CLICK_BUTTON_ACTION,
      label: 'compare_all_plans',
    },
    learnAboutFeaturesClick: {
      action: CLICK_BUTTON_ACTION,
      label: 'learn_about_features',
    },
  },
  resizeEventDebounceMS: RESIZE_EVENT_DEBOUNCE_MS,
  disabledBreakpoints: ['xs', 'sm'],
  trialEndDateFormatString: 'mmmm d',
};

export const DUO_PRO_TRIAL_POPOVER_CONTENT = s__(`DuoProTrial|Your trial ends on
      %{strongStart}%{trialEndDate}%{strongEnd}. We hope you’re enjoying the
      features of GitLab Duo Pro. To continue using your AI-powered assistant
      after you trial ends, you'll need to buy an add-on subscription.`);
export const DUO_PRO_TRIAL_POPOVER_LEARN_TITLE = s__('DuoProTrial|Learn about features');
export const DUO_PRO_TRIAL_POPOVER_PURCHASE_TITLE = s__('DuoProTrial|Purchase now');
export const DUO_PRO_TRIAL_POPOVER_TRACKING_CATEGORY = 'duo_pro_trial_status_popover';
