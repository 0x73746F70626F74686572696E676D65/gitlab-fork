import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  mockPageInfo,
  validCreateResponse,
} from 'ee_jest/groups/settings/compliance_frameworks/mock_data';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import createComplianceFrameworkMutation from 'ee/groups/settings/compliance_frameworks/graphql/queries/create_compliance_framework.mutation.graphql';
import getSppLinkedProjectsNamespaces from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_namespaces.graphql';

const defaultNodes = [
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 1),
    name: 'A1',
    default: true,
    description: 'description 1',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 1',
    projects: { nodes: [] },
  },
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 2),
    name: 'B2',
    default: false,
    description: 'description 2',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 2',
    projects: {
      nodes: [
        {
          id: '1',
          name: 'project-1',
          webUrl: 'gid://gitlab/Project/1',
        },
      ],
    },
  },
  {
    id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 3),
    name: 'a3',
    default: true,
    description: 'description 3',
    color: '#cd5b45',
    pipelineConfigurationFullPath: 'path 3',
    projects: {
      nodes: [
        {
          id: '1',
          name: 'project-1',
          webUrl: 'gid://gitlab/Project/1',
        },
        {
          id: '2',
          name: 'project-2',
          webUrl: 'gid://gitlab/Project/2',
        },
      ],
    },
  },
];

export const createSppLinkedItemsHandler = ({ projects = [], namespaces = [] } = {}) =>
  jest.fn().mockResolvedValue({
    data: {
      project: {
        id: '1',
        securityPolicyProjectLinkedProjects: {
          nodes: projects,
        },
        securityPolicyProjectLinkedNamespaces: {
          nodes: namespaces,
        },
      },
    },
  });

export const mockApolloHandlers = (nodes = defaultNodes) => {
  return {
    complianceFrameworks: jest.fn().mockResolvedValue({
      data: {
        namespace: {
          id: 1,
          name: 'name',
          complianceFrameworks: {
            pageInfo: mockPageInfo(),
            nodes,
          },
        },
      },
    }),
    createFrameworkHandler: jest.fn().mockResolvedValue(validCreateResponse),
  };
};

export const createMockApolloProvider = (handlers) => {
  Vue.use(VueApollo);

  return createMockApollo([
    [getComplianceFrameworkQuery, handlers.complianceFrameworks],
    [createComplianceFrameworkMutation, handlers.createFrameworkHandler],
    [getSppLinkedProjectsNamespaces, handlers.sppLinkedItemsHandler],
  ]);
};
