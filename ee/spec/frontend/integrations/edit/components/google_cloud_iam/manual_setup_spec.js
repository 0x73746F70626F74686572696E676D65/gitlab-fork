import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { STATE_GUIDED } from 'ee/integrations/edit/components/google_cloud_iam/constants';
import ManualSetup from 'ee/integrations/edit/components/google_cloud_iam/manual_setup.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

describe('ManualSetup', () => {
  const wlifIssuer = 'https://test.com';
  let wrapper;
  const createComponent = () => {
    wrapper = shallowMount(ManualSetup, {
      propsData: {
        wlifIssuer,
      },
      stubs: { GlSprintf },
    });
  };

  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findClipboardButtons = () => wrapper.findAllComponents(ClipboardButton);

  beforeEach(() => {
    createComponent();
  });

  describe('Switch to guided setup link', () => {
    let switchLink;

    beforeEach(() => {
      switchLink = findLinks().at(0);
    });

    it('renders link', () => {
      expect(switchLink.text()).toBe('Switch to the guided setup');
    });

    it('emits `show` event', () => {
      expect(wrapper.emitted().show).toBeUndefined();

      switchLink.vm.$emit('click');

      expect(wrapper.emitted().show).toHaveLength(1);
      expect(wrapper.emitted().show[0]).toContain(STATE_GUIDED);
    });
  });

  it('renders links to help doc page and corresponding clipboard button', () => {
    const helpPath = '/help/integration/google_cloud_iam#with-the-google-cloud-cli';
    expect(findLinks().at(2).attributes('href')).toBe(helpPath);
    expect(findClipboardButtons().at(0).props('text')).toBe(helpPath);
  });

  it('show the workload identity federation provider issuer and corresponding clipboard button', () => {
    expect(wrapper.text()).toContain(wlifIssuer);
    expect(findClipboardButtons().at(1).props('text')).toBe(wlifIssuer);
  });
});
