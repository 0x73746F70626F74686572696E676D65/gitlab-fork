import { ROTATION_PERIOD_TWO_WEEKS } from 'ee/ci/secrets/constants';

export const mockProjectEnvironments = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/20',
      environments: {
        __typename: 'EnvironmentConnection',
        nodes: [
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/56',
            name: 'project_env_development',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/55',
            name: 'project_env_production',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/57',
            name: 'project_env_staging',
          },
        ],
      },
    },
  },
};

export const mockGroupEnvironments = {
  data: {
    group: {
      __typename: 'Group',
      id: 'gid://gitlab/Group/96',
      environmentScopes: {
        __typename: 'CiGroupEnvironmentScopeConnection',
        nodes: [
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_development',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_production',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_staging',
          },
        ],
      },
    },
  },
};

export const mockSecretId = 44;

export const mockSecret = ({ customSecret } = {}) => ({
  __typename: 'Secret',
  id: mockSecretId,
  environment: 'staging',
  createdAt: '2024-01-22T08:04:26.024Z',
  expiration: '2029-01-22T08:04:26.024Z',
  description: 'This is a secret',
  key: 'APP_PWD',
  name: 'APP_PWD',
  rotationPeriod: ROTATION_PERIOD_TWO_WEEKS.value,
  ...customSecret,
});

export const mockProjectSecret = ({ customSecret, errors = [] } = {}) => ({
  secret: {
    ...mockSecret(customSecret),
  },
  errors,
});

export const mockProjectSecretQueryResponse = ({ customSecret } = {}) => ({
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/19',
      fullPath: '/path/to/project',
      secret: {
        ...mockSecret(),
        ...customSecret,
      },
    },
  },
});
