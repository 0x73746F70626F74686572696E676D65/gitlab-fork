import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import ObservabilitySettings from './components/settings_form.vue';

export default () => {
  initSimpleApp('.js-observability-settings', ObservabilitySettings);
};
