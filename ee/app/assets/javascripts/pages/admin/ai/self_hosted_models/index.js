import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import SelfHostedModelsApp from './components/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

function mountSelfHostedModelsApp() {
  const el = document.getElementById('js-self-hosted-models');

  if (!el) {
    return null;
  }

  const { basePath, newSelfHostedModelPath } = el.dataset;

  return new Vue({
    el,
    name: 'SelfHostedModelsApp',
    apolloProvider,
    render: (h) =>
      h(SelfHostedModelsApp, {
        props: {
          basePath,
          newSelfHostedModelPath,
        },
      }),
  });
}

mountSelfHostedModelsApp();
