import { dateAndTimeToISOString } from '~/lib/utils/datetime_utility';
import { mockProjectSecretsData } from '../mock_data';
import getSecretsQuery from './queries/client/get_secrets.query.graphql';
import getSecretDetailsQuery from './queries/client/get_secret_details.query.graphql';

export const cacheConfig = {
  typePolicies: {
    Query: {
      fields: {
        group: {
          merge(existing = {}, incoming, { isReference }) {
            if (isReference(incoming)) {
              return existing;
            }
            return { ...existing, ...incoming };
          },
        },
        project: {
          merge(existing = {}, incoming, { isReference }) {
            if (isReference(incoming)) {
              return existing;
            }
            return { ...existing, ...incoming };
          },
        },
      },
    },
  },
};

// client-only field pagination
// return a slice of the cached data according to offset and limit
const clientSidePaginate = (sourceData, offset, limit) => ({
  ...sourceData,
  nodes: sourceData.nodes.slice(offset, offset + limit),
});

export const resolvers = {
  Group: {
    secrets({ fullPath }, { offset, limit }, { cache }) {
      const sourceData = cache.readQuery({
        query: getSecretsQuery,
        variables: { fullPath, isGroup: true },
      }).group.secrets;

      return clientSidePaginate(sourceData, offset, limit);
    },
  },
  Project: {
    secrets({ fullPath }, { offset, limit }, { cache }) {
      const sourceData = cache.readQuery({
        query: getSecretsQuery,
        variables: { fullPath, isProject: true },
      }).project.secrets;

      return clientSidePaginate(sourceData, offset, limit);
    },
    secret({ fullPath }, { id }, { cache }) {
      const sourceData = cache.readQuery({
        query: getSecretDetailsQuery,
        variables: { fullPath, id },
      });

      if (sourceData) {
        return sourceData;
      }

      return mockProjectSecretsData[id - 1] || mockProjectSecretsData[0];
    },
  },
  Mutation: {
    createSecret: async (_, { fullPath, secret }, { cache }) => {
      const id = mockProjectSecretsData.length + 1;
      cache.writeQuery({
        query: getSecretDetailsQuery,
        variables: { fullPath, id },
        data: {
          project: {
            id: 'gid://gitlab/Project/19',
            fullPath,
            secret: {
              id,
              ...secret,
              createdAt: dateAndTimeToISOString(new Date(), '00:00'),
              expiration: dateAndTimeToISOString(secret.expiration, '00:00'),
              // eslint-disable-next-line @gitlab/require-i18n-strings
              __typename: 'Secret',
            },
          },
        },
      });

      const mockGraphQLResponse = {
        secret: {
          ...secret,
          id,
        },
        errors: [],
      };

      // simulate mock fetch to test loading icon behavior
      return new Promise((resolve) => {
        setTimeout(() => {
          resolve(mockGraphQLResponse);
        }, 2000);
      });
    },
  },
};
