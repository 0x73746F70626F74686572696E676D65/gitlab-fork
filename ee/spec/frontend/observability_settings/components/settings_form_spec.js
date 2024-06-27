import { GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SettingsForm from 'ee/observability_settings/components/settings_form.vue';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

describe('SettingsForm', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(SettingsForm, {
      stubs: { GlSprintf },
    });
  });

  const findContent = () => wrapper.find('.settings-content');
  it('renders a title', () => {
    expect(wrapper.find('.settings-title').text()).toBe('Tracing, Metrics & Logs');
  });

  it('renders a subtitle', () => {
    expect(wrapper.find('.gl-text-secondary').text()).toBe(
      'Enable tracing, metrics, or logs on your project.',
    );
  });

  it('renders an expand button', () => {
    expect(wrapper.findComponent(GlButton).text()).toBe('Expand');
    expect(wrapper.findComponent(GlButton).classes('js-settings-toggle')).toBe(true);
  });

  it('renders an intro text with link', () => {
    expect(findContent().text()).toBe(
      'View our documentation for further instructions on how to use these features.',
    );
    expect(findContent().findComponent(GlLink).attributes('href')).toBe(
      `${DOCS_URL_IN_EE_DIR}/operations`,
    );
  });
});
