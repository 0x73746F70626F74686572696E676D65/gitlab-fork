import '~/pages/groups/edit';
import initAccessRestrictionField from 'ee/groups/settings/access_restriction_field';
import validateRestrictedIpAddress from 'ee/groups/settings/access_restriction_field/validate_ip_address';
import { initGroupPermissionsFormSubmit } from 'ee/groups/settings/permissions';
import { initServicePingSettingsClickTracking } from 'ee/registration_features_discovery_message';
import { createAlert } from '~/alert';
import { initMergeRequestMergeChecksApp } from 'ee/merge_checks';
import { __ } from '~/locale';

initGroupPermissionsFormSubmit();

initAccessRestrictionField({
  selector: '.js-allowed-email-domains',
  props: {
    placeholder: __('example.com'),
    regexErrorMessage: __('The domain you entered is misformatted.'),
    disallowedValueErrorMessage: __('The domain you entered is not allowed.'),
  },
});

initAccessRestrictionField({
  selector: '.js-ip-restriction',
  props: { placeholder: __('192.168.0.0/24 or 2001:0DB8:1234::/48') },
  testid: 'ip-restriction-field',
  customValidator: validateRestrictedIpAddress,
});

const mergeRequestApprovalSetting = document.querySelector('#js-merge-request-approval-settings');

if (mergeRequestApprovalSetting) {
  (async () => {
    try {
      const { mountGroupApprovalSettings } = await import(
        /* webpackChunkName: 'mountGroupApprovalSettings' */ 'ee/approvals/group_settings/mount_group_settings'
      );
      mountGroupApprovalSettings(mergeRequestApprovalSetting);
    } catch (error) {
      createAlert({
        message: __('An error occurred while loading a section of this page.'),
        captureError: true,
        error: `Error mounting group approval settings component: #{error.message}`,
      });
    }
  })();
}

initServicePingSettingsClickTracking();
initMergeRequestMergeChecksApp();
