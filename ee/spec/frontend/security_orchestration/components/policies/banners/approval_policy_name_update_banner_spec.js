import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import ApprovalPolicyNameUpdateBanner from 'ee/security_orchestration/components/policies/banners/approval_policy_name_update_banner.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';

describe('ApprovalPolicyNameUpdateBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ApprovalPolicyNameUpdateBanner, {
      stubs: {
        GlAlert,
        GlSprintf,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);

  beforeEach(() => {
    createComponent();
  });

  it('renders alert info with message', () => {
    expect(findLocalStorageSync().exists()).toBe(true);
    expect(findAlert().exists()).toBe(true);
    expect(trimText(findAlert().text())).toContain(
      'Updated policy name The Scan result policy is now called the Merge request approval policy to better align with its purpose. For more details, see the release notes.',
    );
  });

  it('dismisses the alert', async () => {
    await findAlert().vm.$emit('dismiss');

    expect(findAlert().exists()).toBe(false);
  });
});
