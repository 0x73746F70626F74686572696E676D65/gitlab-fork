import { variableTypes, groupString, instanceString } from '~/ci_variable_list/constants';

export const devName = 'dev';
export const prodName = 'prod';

export const mockVariables = (kind) => {
  return [
    {
      __typename: `Ci${kind}Variable`,
      id: 1,
      key: 'my-var',
      masked: false,
      protected: true,
      value: 'env_val',
      variableType: variableTypes.variableType,
    },
    {
      __typename: `Ci${kind}Variable`,
      id: 2,
      key: 'secret',
      masked: true,
      protected: false,
      value: 'the_secret_value',
      variableType: variableTypes.fileType,
    },
  ];
};

export const mockVariablesWithScopes = (kind) =>
  mockVariables(kind).map((variable) => {
    return { ...variable, environmentScope: '*' };
  });

const createDefaultVars = ({ withScope = true, kind } = {}) => {
  let base = mockVariables(kind);

  if (withScope) {
    base = mockVariablesWithScopes(kind);
  }

  return {
    __typename: `Ci${kind}VariableConnection`,
    nodes: base,
  };
};

const defaultEnvs = {
  __typename: 'EnvironmentConnection',
  nodes: [
    {
      __typename: 'Environment',
      id: 1,
      name: prodName,
    },
    {
      __typename: 'Environment',
      id: 2,
      name: devName,
    },
  ],
};

export const mockEnvs = defaultEnvs.nodes;

export const mockProjectEnvironments = {
  data: {
    project: {
      __typename: 'Project',
      id: 1,
      environments: defaultEnvs,
    },
  },
};

export const mockProjectVariables = {
  data: {
    project: {
      __typename: 'Project',
      id: 1,
      ciVariables: createDefaultVars(),
    },
  },
};

export const mockGroupVariables = {
  data: {
    group: {
      __typename: 'Group',
      id: 1,
      ciVariables: createDefaultVars({ kind: groupString }),
    },
  },
};

export const mockAdminVariables = {
  data: {
    ciVariables: createDefaultVars({ withScope: false, kind: instanceString }),
  },
};

export const newVariable = {
  id: 3,
  environmentScope: 'new',
  key: 'AWS_RANDOM_THING',
  masked: true,
  protected: false,
  value: 'devops',
  variableType: variableTypes.variableType,
};
