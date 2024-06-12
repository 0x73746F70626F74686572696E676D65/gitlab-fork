import createMockApollo from 'helpers/mock_apollo_helper';
import {
  defaultProvide,
  selfManagedUsersQueuedForRolePromotion,
} from 'ee_jest/admin/role_promotion_requests/mock_data';
import usersQueuedForLicenseSeat from '../graphql/users_queued_for_license_seat.query.graphql';
import RolePromotionRequestsApp from './app.vue';

const meta = {
  title: 'ee/admin/role_promotion_requests/app',
  component: RolePromotionRequestsApp,
};

export default meta;

const createTemplate = (config = {}) => {
  let { provide, apolloProvider } = config;

  if (provide == null) {
    provide = {};
  }

  if (apolloProvider == null) {
    const requestHandlers = [
      [usersQueuedForLicenseSeat, () => Promise.resolve(selfManagedUsersQueuedForRolePromotion)],
    ];
    apolloProvider = createMockApollo(requestHandlers);
  }

  return (args, { argTypes }) => ({
    components: { RolePromotionRequestsApp },
    apolloProvider,
    provide: {
      ...defaultProvide,
      ...provide,
    },
    props: Object.keys(argTypes),
    template: '<role-promotion-requests-app />',
  });
};

export const Default = {
  render: createTemplate(),
};

export const Loading = {
  render: (...args) => {
    const apolloProvider = createMockApollo([
      [usersQueuedForLicenseSeat, () => new Promise(() => {})],
    ]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};

export const Error = {
  render: (...args) => {
    const apolloProvider = createMockApollo([[usersQueuedForLicenseSeat, () => Promise.reject()]]);

    return createTemplate({
      apolloProvider,
    })(...args);
  },
};
