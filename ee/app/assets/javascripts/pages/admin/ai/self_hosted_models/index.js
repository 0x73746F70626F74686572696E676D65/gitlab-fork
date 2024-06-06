import Vue from 'vue';
import CustomModelsSettingsApp from './app.vue';

function mountCustomModelsApp() {
  const el = document.getElementById('js-custom-models');

  if (!el) {
    return null;
  }

  return new Vue({
    el,
    name: 'CustomModelsApp',
    render: (h) =>
      h(CustomModelsSettingsApp, {
        props: {
          models: JSON.parse(el.dataset.customModels),
        },
      }),
  });
}

mountCustomModelsApp();
