import Vue from 'vue';
import VueRouter from 'vue-router';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetailsWrapper from 'ee/ci/secrets/components/secret_details/secret_details_wrapper.vue';
import SecretFormWrapper from 'ee/ci/secrets/components/secret_form/secret_form_wrapper.vue';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import createRouter from 'ee/ci/secrets/router';
import { ENTITY_GROUP } from 'ee/ci/secrets/constants';
import SecretsApp from 'ee//ci/secrets/components/secrets_app.vue';

Vue.use(VueRouter);

describe('Secrets router', () => {
  let wrapper;
  const base = '/-/secrets';
  const groupProps = {
    groupId: '1',
    groupPath: '/path/to/group',
  };

  const projectProps = {
    projectId: '2',
    projectPath: '/path/to/project',
  };

  const createSecretsApp = ({ route, props } = {}) => {
    const router = createRouter(base, props);
    if (route) {
      router.push(route);
    }

    wrapper = mountExtended(SecretsApp, {
      router,
      propsData: { ...props },
      data() {
        return {
          secrets: [],
        };
      },
      mocks: {
        $apollo: {
          queries: {
            environments: { loading: true },
            secrets: { loading: false },
          },
        },
      },
    });
  };

  it.each`
    path              | componentNames            | components
    ${'/'}            | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/?page=2'}     | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/new'}         | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
    ${'/key/details'} | ${'SecretDetailsWrapper'} | ${[SecretDetailsWrapper]}
    ${'/key/edit'}    | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
  `('uses $componentNames for path "$path"', ({ path, components }) => {
    const router = createRouter(base, groupProps);

    expect(router.getMatchedComponents(path)).toStrictEqual(components);
  });

  it.each`
    path                   | redirect
    ${'/key'}              | ${'/key/details'}
    ${'/key/unknownroute'} | ${'/'}
  `('redirects from $path to $redirect', async ({ path, redirect }) => {
    const router = createRouter(base, groupProps);

    await router.push(path);

    expect(router.currentRoute.path).toBe(redirect);
  });

  describe.each`
    entity       | props           | fullPath
    ${'group'}   | ${groupProps}   | ${groupProps.groupPath}
    ${'project'} | ${projectProps} | ${projectProps.projectPath}
  `('$entity secrets form', ({ entity, props, fullPath }) => {
    it('provides the correct props when visiting the index', () => {
      createSecretsApp({ route: '/', props });

      expect(wrapper.findComponent(SecretsTable).props()).toMatchObject({
        isGroup: entity === ENTITY_GROUP,
        fullPath,
      });
    });

    it('provides the correct props when visiting the create form', () => {
      createSecretsApp({ route: '/new', props });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        entity,
        fullPath,
      });
    });

    it('provides the correct props when visiting the edit form', () => {
      const route = { name: 'edit', params: { id: '123' } };
      createSecretsApp({ route, props });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        entity,
        fullPath,
        isEditing: true,
        secretId: 123,
      });
    });
  });
});
