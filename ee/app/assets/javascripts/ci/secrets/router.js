import Vue from 'vue';
import VueRouter from 'vue-router';
import { __, s__ } from '~/locale';
import {
  AUDIT_LOG_ROUTE_NAME,
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  ENTITY_GROUP,
  ENTITY_PROJECT,
  INDEX_ROUTE_NAME,
  NEW_ROUTE_NAME,
} from './constants';
import SecretsTable from './components/secrets_table/secrets_table.vue';
import SecretFormWrapper from './components/secret_form/secret_form_wrapper.vue';
import SecretTabs from './components/secret_details/secret_tabs.vue';
import SecretDetails from './components/secret_details/secret_details.vue';
import SecretAuditLog from './components/secret_details/secret_audit_log.vue';

Vue.use(VueRouter);

export default (base, props) => {
  const { groupPath, projectPath } = props;

  const entity = projectPath ? ENTITY_PROJECT : ENTITY_GROUP;
  const fullPath = projectPath || groupPath;
  const isGroup = entity === ENTITY_GROUP;

  return new VueRouter({
    mode: 'history',
    base,
    routes: [
      {
        name: INDEX_ROUTE_NAME,
        path: '/',
        component: SecretsTable,
        props: () => {
          return { isGroup, fullPath };
        },
        meta: {
          getBreadcrumbText: () => s__('Secrets|Secrets'),
          isRoot: true,
        },
      },
      {
        name: NEW_ROUTE_NAME,
        path: '/new',
        component: SecretFormWrapper,
        props: () => {
          return { entity, fullPath };
        },
        meta: {
          getBreadcrumbText: () => s__('Secrets|New secret'),
        },
      },
      {
        path: '/:id',
        component: SecretTabs,
        props: ({ params: { id }, name }) => {
          return { fullPath, secretId: Number(id), routeName: name };
        },
        children: [
          {
            name: DETAILS_ROUTE_NAME,
            path: 'details',
            component: SecretDetails,
            meta: {
              getBreadcrumbText: ({ id }) => id,
              isDetails: true,
            },
          },
          {
            name: AUDIT_LOG_ROUTE_NAME,
            path: 'auditlog',
            component: SecretAuditLog,
            meta: {
              getBreadcrumbText: () => s__('Secrets|Audit log'),
            },
          },
          {
            path: '',
            redirect: 'details',
          },
        ],
      },
      {
        name: EDIT_ROUTE_NAME,
        path: '/:id/edit',
        component: SecretFormWrapper,
        props: ({ params: { id } }) => {
          return {
            entity,
            fullPath,
            isEditing: true,
            secretId: Number(id),
          };
        },
        meta: {
          getBreadcrumbText: () => __('Edit'),
        },
      },
      {
        path: '*',
        redirect: '/',
      },
    ],
  });
};
