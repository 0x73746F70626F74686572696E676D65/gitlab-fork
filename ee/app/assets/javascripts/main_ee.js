import initEETrialBanner from 'ee/ee_trial_banner';
import initNamespaceUserCapReachedAlert from 'ee/namespace_user_cap_reached_alert';
import { initTanukiBotChatDrawer } from 'ee/ai/tanuki_bot';
import { initSamlReloadModal } from 'ee/saml_sso/index';

if (document.querySelector('.js-verification-reminder') !== null) {
  // eslint-disable-next-line promise/catch-or-return
  import('ee/billings/verification_reminder').then(({ default: initVerificationReminder }) => {
    initVerificationReminder();
  });
}

// EE specific calls
initEETrialBanner();
initNamespaceUserCapReachedAlert();

initTanukiBotChatDrawer();
initSamlReloadModal();
