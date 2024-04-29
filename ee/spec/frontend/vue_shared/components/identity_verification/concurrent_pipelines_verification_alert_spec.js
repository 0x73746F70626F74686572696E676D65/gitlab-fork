import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import ConcurrentPipelinesVerificationAlert from 'ee/vue_shared/components/identity_verification/concurrent_pipelines_verification_alert.vue';

describe('Concurrent pipelines verification alert', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(ConcurrentPipelinesVerificationAlert, {
      provide: {
        identityVerificationPath: 'identity/verification/path',
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    createWrapper();
  });

  it('shows alert with expected props', () => {
    expect(findAlert().props()).toMatchObject({
      title: 'Before you can run concurrent pipelines, we need to verify your account.',
      primaryButtonText: 'Verify my account',
      primaryButtonLink: 'identity/verification/path',
      variant: 'warning',
    });
  });

  it('shows alert with expected description', () => {
    expect(findAlert().text()).toBe(
      `We won't ask you for this information again. It will never be used for marketing purposes.`,
    );
  });

  it(`hides the alert when it's dismissed`, async () => {
    findAlert().vm.$emit('dismiss');
    await nextTick();

    expect(findAlert().exists()).toBe(false);
  });
});
